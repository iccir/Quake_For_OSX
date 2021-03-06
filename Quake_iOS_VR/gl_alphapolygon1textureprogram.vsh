//
//  gl_alphapolygon1textureprogram.vsh
//  Quake_iOS_VR
//
//  Created by Heriberto Delgado on 5/18/16.
//
//

attribute vec3 position;
attribute vec2 texcoords;

varying vec2 texcoords_fragment;

uniform mat4 transform;

invariant gl_Position;

void main()
{
    gl_Position = transform * vec4(position, 1.0);
    
    texcoords_fragment = texcoords;
}
