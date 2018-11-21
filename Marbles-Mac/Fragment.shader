#pragma body

float mixLevel = 0.8;
vec3 gray = vec3(dot(vec3(0.3, 0.59, 0.11), _output.color.rgb));
_output.color = vec4( rand(32910,321,954),
rand(329410,321,954),
rand(32910,3121,954),
1.0);// mix(_output.color, vec4(gray, 1.0), mixLevel);
