#version 150

in vec4 position;
in vec3 normal;
in vec4 uv0;
in vec4 uv1;

out vec4 colour;
out vec4 oUv0;
out vec4 oUv1;

uniform vec4 worldMatrix3x4Array[240];
uniform mat4 viewProjectionMatrix;
uniform vec4 lightPos;
uniform vec4 ambient;
uniform vec4 lightDiffuseColour;

void main()
{
	// transform by indexed matrix
	// perform matrix multiplication manually since no 3x4 matrices
	vec3 transformedPos;
	vec3 transformedNorm;
	int instanceOffset = int(uv1.x) * 3;
	for (int row = 0; row < 3; ++row)
	{
		vec4 matrixRow = worldMatrix3x4Array[instanceOffset + row];
		transformedPos[row] = dot(matrixRow, position);
#if SHADOW_CASTER
#else
		transformedNorm[row] = dot(matrixRow.xyz, normal);
#endif
	}

	// view / projection
	gl_Position = viewProjectionMatrix * vec4(transformedPos,1);
	oUv0 = uv0;
    colour = vec4(0);

#if SHADOW_CASTER
	colour = ambient;
#else
	vec3 lightDir = normalize(
		lightPos.xyz - (transformedPos.xyz * lightPos.w));
	colour = ambient + clamp(dot(lightDir, transformedNorm),0.0,1.0) * lightDiffuseColour;
#endif
}
