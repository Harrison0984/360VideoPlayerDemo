 
precision mediump float;
uniform sampler2D SamplerY;
uniform sampler2D SamplerUV;
varying mediump vec2 v_textureCoordinate;

uniform mat3 colorConversionMatrix;

void main() {
    mediump vec3 yuv;
    lowp vec3 rgb;
    
    yuv.x = (texture2D(SamplerY, v_textureCoordinate).r - (16.0/255.0))* 1.0;
    yuv.yz = (texture2D(SamplerUV, v_textureCoordinate).rg - vec2(0.5, 0.5))* 1.0;
    
    rgb = colorConversionMatrix * yuv;
    
    gl_FragColor = vec4(rgb,1);
}