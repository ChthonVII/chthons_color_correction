#version 450



layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OriginalSize;
    vec4 OutputSize;
    uint FrameCount;
    float PHOSPHOR_LAYOUT;
    float APERATURE_GRILLE_STRENGTH;
    float MONITOR_SUBPIXELS;
} params;

#pragma parameter PHOSPHOR_LAYOUT "PHOSPHOR LAYOUT [1-6 Aperture, 7-10 Shadow, 11-14 Slot]" 4.0 0.0 15.0 1.0
#pragma parameter APERATURE_GRILLE_STRENGTH "APERATURE GRILL EFFECT STRENGTH" 0.4 0.0 1.0 0.01
#pragma parameter MONITOR_SUBPIXELS "MONITOR SUBPIXELS LAYOUT [0=RGB, 1=BGR]" 0.0 0.0 1.0 1.0

#define APERATURE_GRILLE_STRENGTH params.APERATURE_GRILLE_STRENGTH

layout(std140, set = 0, binding = 0) uniform UBO
{
	mat4 MVP;
} global;



#define saturate(c) clamp(c, 0.0, 1.0)



#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 1) in vec2 FragCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;



vec3 new_mask_weights(vec2 coord, int phosphor_layout, float monitor_subpixels, vec3 basecolor){

   vec3 weights = vec3(1.0, 1.0, 1.0);
   // ratio of pixels in the mask that lose to pixels that gain
   // example: For basic RGB mask, two pixels lose each color, and one pixel gains it
   float ratios[5] = float[5](99.0, 1.0, 1.0, 2.0, 1.0); // array is padded with a dummy value in front
   float gain = ratios[phosphor_layout];
   float adjgain = gain * APERATURE_GRILLE_STRENGTH;
   float adjloss = APERATURE_GRILLE_STRENGTH;
   float on = 1.0 + adjgain;
   float off = 1.0 - adjloss;

   bvec3 basecolornonzero = greaterThan(basecolor, vec3(0.0));
   vec3 max_on = vec3(1.0)/basecolor;
   max_on = mix(vec3(on), max_on, basecolornonzero);
   vec3 max_gain = max_on - vec3(1.0);
   // for now, support modes 4 and 2 -- 1-to-1 or 1-to-2
   //float max_loss_factor = phosphor_layout == 4 ? 1.0 : 0.5;
   float max_loss_factor = 1.0 / ratios[phosphor_layout];
   vec3 max_loss = max_gain * vec3(max_loss_factor);
   vec3 max_off = vec3(1.0) - max_loss;

   // refactor
   float red_on = min(on, max_on.x);
   float red_off = max(off, max_off.x);
   float green_on = min(on, max_on.y);
   float green_off = max(off, max_off.y);
   float blue_on = min(on, max_on.z);
   float blue_off = max(off, max_off.z);

   // apparently, these are supposed to be backwards to the monitor's layout?
   vec3 red     = monitor_subpixels==1.0 ? vec3(red_on,  green_off, blue_off) : vec3(red_off, green_off, blue_on);
   vec3 green   = vec3(red_off, green_on,  blue_off);
   vec3 blue    = monitor_subpixels==1.0 ? vec3(red_off, green_off, blue_on ) : vec3(red_on,  green_off, blue_off);
   vec3 magenta = vec3(red_on,  green_off, blue_on );
   vec3 yellow  = monitor_subpixels==1.0 ? vec3(red_on,  green_on,  blue_off) : vec3(red_off, green_on,  blue_on );
   vec3 cyan    = monitor_subpixels==1.0 ? vec3(red_off, green_on,  blue_on ) : vec3(red_on,  green_on,  blue_off);
   //vec3 black   = vec3(red_off, green_off, blue_off);
   //vec3 white   = vec3(red_on, green_on, blue_on );

   int w, z = 0;

   // This pattern is used by a few layouts, so we'll define it here
   //vec3 aperture_weights = mix(magenta, green, floor(mod(coord.x, 2.0)));

   // for now, implement modes 2 and 4

   if(phosphor_layout == 3){
      // Classic RGB layout; good for 1080p and lower
      vec3 bw3[3] = vec3[](red, green, blue);

      z = int(floor(mod(coord.x, 3.0)));

      weights = bw3[z];
      return weights;
   }

   else if (phosphor_layout == 4) {
   // reduced TVL aperture for RGB panels. Good for 4k.
      // aperture_2_4_rgb

      vec3 big_ap_rgb[4] = vec3[](red, yellow, cyan, blue);

      w = int(floor(mod(coord.x, 4.0)));

      weights = big_ap_rgb[w];
      return weights;
   }

   // TODO: Implement other masks

   // fall through
   return weights;

}


/* Mask code pasted from subpixel_masks.h. Masks 3 and 4 added. */
/*
vec3 mask_weights(vec2 coord, int phosphor_layout, float monitor_subpixels){
   vec3 weights = vec3(1.,1.,1.);
   float on = 1.+MASK_LIGHT_STRENGTH;
   float off = 1.-APERATURE_GRILLE_STRENGTH;
   vec3 red     = monitor_subpixels==1.0 ? vec3(on,  off, off) : vec3(off, off, on );
   vec3 green   = vec3(off, on,  off);
   vec3 blue    = monitor_subpixels==1.0 ? vec3(off, off, on ) : vec3(on,  off, off);
   vec3 magenta = vec3(on,  off, on );
   vec3 yellow  = monitor_subpixels==1.0 ? vec3(on,  on,  off) : vec3(off, on,  on );
   vec3 cyan    = monitor_subpixels==1.0 ? vec3(off, on,  on ) : vec3(on,  on,  off);
   vec3 black   = vec3(off, off, off);
   vec3 white   = vec3(on,  on,  on );
   int w, z = 0;
   
   // This pattern is used by a few layouts, so we'll define it here
   vec3 aperture_weights = mix(magenta, green, floor(mod(coord.x, 2.0)));
   
   if(phosphor_layout == 0) return weights;

   else if(phosphor_layout == 1){
      // classic aperture for RGB panels; good for 1080p, too small for 4K+
      // aka aperture_1_2_bgr
      weights  = aperture_weights;
      return weights;
   }

   else if(phosphor_layout == 2){
      // Classic RGB layout; good for 1080p and lower
      vec3 bw3[3] = vec3[](red, green, blue);
//      vec3 bw3[3] = vec3[](black, yellow, blue);
      
      z = int(floor(mod(coord.x, 3.0)));
      
      weights = bw3[z];
      return weights;
   }

   else if(phosphor_layout == 3){
      // black and white aperture; good for weird subpixel layouts and low brightness; good for 1080p and lower
      vec3 bw3[3] = vec3[](black, white, black);
      
      z = int(floor(mod(coord.x, 3.0)));
      
      weights = bw3[z];
      return weights;
   }

   else if(phosphor_layout == 4){
      // reduced TVL aperture for RGB panels. Good for 4k.
      // aperture_2_4_rgb
      
      vec3 big_ap_rgb[4] = vec3[](red, yellow, cyan, blue);
      
      w = int(floor(mod(coord.x, 4.0)));
      
      weights = big_ap_rgb[w];
      return weights;
   }
   
   else if(phosphor_layout == 5){
      // black and white aperture; good for weird subpixel layouts and low brightness; good for 4k 
      vec3 bw4[4] = vec3[](black, black, white, white);
      
      z = int(floor(mod(coord.x, 4.0)));
      
      weights = bw4[z];
      return weights;
   }

   else if(phosphor_layout == 6){
      // aperture_1_4_rgb; good for simulating lower 
      vec3 ap4[4] = vec3[](red, green, blue, black);
      
      z = int(floor(mod(coord.x, 4.0)));
      
      weights = ap4[z];
      return weights;
   }

   else if(phosphor_layout == 7){
      // 2x2 shadow mask for RGB panels; good for 1080p, too small for 4K+
      // aka delta_1_2x1_bgr
      vec3 inverse_aperture = mix(green, magenta, floor(mod(coord.x, 2.0)));
      weights               = mix(aperture_weights, inverse_aperture, floor(mod(coord.y, 2.0)));
      return weights;
   }

   else if(phosphor_layout == 8){
      // delta_2_4x1_rgb
      vec3 delta[2][4] = {
         {red, yellow, cyan, blue},
         {cyan, blue, red, yellow}
      };
      
      w = int(floor(mod(coord.y, 2.0)));
      z = int(floor(mod(coord.x, 4.0)));
      
      weights = delta[w][z];
      return weights;
   }

   else if(phosphor_layout == 9){
      // delta_1_4x1_rgb; dunno why this is called 4x1 when it's obviously 4x2 /shrug
      vec3 delta1[2][4] = {
         {red,  green, blue, black},
         {blue, black, red,  green}
      };
      
      w = int(floor(mod(coord.y, 2.0)));
      z = int(floor(mod(coord.x, 4.0)));
      
      weights = delta1[w][z];
      return weights;
   }
   
   else if(phosphor_layout == 10){
      // delta_2_4x2_rgb
      vec3 delta[4][4] = {
         {red,  yellow, cyan, blue},
         {red,  yellow, cyan, blue},
         {cyan, blue,   red,  yellow},
         {cyan, blue,   red,  yellow}
      };
      
      w = int(floor(mod(coord.y, 4.0)));
      z = int(floor(mod(coord.x, 4.0)));
      
      weights = delta[w][z];
      return weights;
   }

   else if(phosphor_layout == 11){
      // slot mask for RGB panels; looks okay at 1080p, looks better at 4K
      vec3 slotmask[4][6] = {
         {red, green, blue,    red, green, blue,},
         {red, green, blue,  black, black, black},
         {red, green, blue,    red, green, blue,},
         {black, black, black, red, green, blue,}
      };
      
      w = int(floor(mod(coord.y, 4.0)));
      z = int(floor(mod(coord.x, 6.0)));

      // use the indexes to find which color to apply to the current pixel
      weights = slotmask[w][z];
      return weights;
   }

   else if(phosphor_layout == 12){
      // slot mask for RGB panels; looks okay at 1080p, looks better at 4K
      vec3 slotmask[4][6] = {
         {black,  white, black,   black,  white, black,},
         {black,  white, black,  black, black, black},
         {black,  white, black,  black,  white, black,},
         {black, black, black,  black,  white, black,}
      };
      
      w = int(floor(mod(coord.y, 4.0)));
      z = int(floor(mod(coord.x, 6.0)));

      // use the indexes to find which color to apply to the current pixel
      weights = slotmask[w][z];
      return weights;
   }

   else if(phosphor_layout == 13){
      // based on MajorPainInTheCactus' HDR slot mask
      vec3 slot[4][8] = {
         {red,   green, blue,  black, red,   green, blue,  black},
         {red,   green, blue,  black, black, black, black, black},
         {red,   green, blue,  black, red,   green, blue,  black},
         {black, black, black, black, red,   green, blue,  black}
      };
      
      w = int(floor(mod(coord.y, 4.0)));
      z = int(floor(mod(coord.x, 8.0)));
      
      weights = slot[w][z];
      return weights;
   }

   else if(phosphor_layout == 14){
      // same as above but for RGB panels
      vec3 slot2[4][10] = {
         {red,   yellow, green, blue,  blue,  red,   yellow, green, blue,  blue },
         {black, green,  green, blue,  blue,  red,   red,    black, black, black},
         {red,   yellow, green, blue,  blue,  red,   yellow, green, blue,  blue },
         {red,   red,    black, black, black, black, green,  green, blue,  blue }
      };
   
      w = int(floor(mod(coord.y, 4.0)));
      z = int(floor(mod(coord.x, 10.0)));
      
      weights = slot2[w][z];
      return weights;
   }
   
   else if(phosphor_layout == 15){
      // slot_3_7x6_rgb
      vec3 slot[6][14] = {
         {red,   red,   yellow, green, cyan,  blue,  blue,  red,   red,   yellow, green,  cyan,  blue,  blue},
         {red,   red,   yellow, green, cyan,  blue,  blue,  red,   red,   yellow, green,  cyan,  blue,  blue},
         {red,   red,   yellow, green, cyan,  blue,  blue,  black, black, black,  black,  black, black, black},
         {red,   red,   yellow, green, cyan,  blue,  blue,  red,   red,   yellow, green,  cyan,  blue,  blue},
         {red,   red,   yellow, green, cyan,  blue,  blue,  red,   red,   yellow, green,  cyan,  blue,  blue},
         {black, black, black,  black, black, black, black, black, red,   red,    yellow, green, cyan,  blue}
      };
      
      w = int(floor(mod(coord.y, 6.0)));
      z = int(floor(mod(coord.x, 14.0)));
      
      weights = slot[w][z];
      return weights;
   }


   
   else return weights;
}
*/

vec4 reallocatecolors(vec4 colors, vec4 control){
   vec4 gains = (vec4(1.0) - colors) * control;
   vec4 losses = colors * (vec4(1.0) - control);
   float totalgain = gains.x + gains.y + gains.z + gains.w;
   float totalloss = losses.x + losses.y + losses.z + losses.w;
   vec4 gainshare = gains / vec4(totalgain);
   vec4 lossshare = losses / vec4(totalloss);
   float totaltransfer = min(totalgain, totalloss) * APERATURE_GRILLE_STRENGTH;
   bool notransfer = totaltransfer <= 0.0;
   vec4 newcolors = notransfer ? colors : colors + (vec4(totaltransfer) * gainshare) - (vec4(totaltransfer) * lossshare);
   return newcolors;
}


void main()
{
    int cycleindex = int(floor(mod(vTexCoord.x * params.OutputSize.x, 4.0)));
    // at 1x scale, we shouldn't need any "snap to center" business.
    vec3 farleft = texture(Source, vTexCoord + vec2((0.0 - cycleindex) * params.OutputSize.z, 0.0)).xyz;
    vec3 midleft = texture(Source, vTexCoord + vec2((1.0 - cycleindex) * params.OutputSize.z, 0.0)).xyz;
    vec3 midright = texture(Source, vTexCoord + vec2((2.0 - cycleindex) * params.OutputSize.z, 0.0)).xyz;
    vec3 farright = texture(Source, vTexCoord + vec2((3.0 - cycleindex) * params.OutputSize.z, 0.0)).xyz;

    vec4 reds = vec4(farleft.r, midleft.r, midright.r, farright.r);
    vec4 greens = vec4(farleft.g, midleft.g, midright.g, farright.g);
    vec4 blues = vec4(farleft.b, midleft.b, midright.b, farright.b);

    vec4 redcontrol = params.MONITOR_SUBPIXELS == 1.0 ? vec4(0.0, 0.0, 1.0, 1.0) : vec4(1.0, 1.0, 0.0, 0.0);
    vec4 greencontrol = vec4(0.0, 1.0, 1.0, 0.0);
    vec4 bluecontrol = params.MONITOR_SUBPIXELS == 1.0 ? vec4(1.0, 1.0, 0.0, 0.0) : vec4(0.0, 0.0, 1.0, 1.0);

    vec4 newreds = reallocatecolors(reds, redcontrol);
    vec4 newgreens = reallocatecolors(greens, greencontrol);
    vec4 newblues = reallocatecolors(blues, bluecontrol);

    vec3 finalcolor = saturate(vec3(newreds[cycleindex], newgreens[cycleindex], newblues[cycleindex]));

    FragColor = vec4(finalcolor, 1.0);
}
