Shader "Custom/AOShader" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
	}
	SubShader {
		Tags {"RenderType"="Opaque"}
		Lighting Off
		Fog { Mode Off }
		
		//LOD 200
		
		CGPROGRAM
// Upgrade NOTE: excluded shader from DX11, Xbox360, OpenGL ES 2.0 because it uses unsized arrays
		#pragma exclude_renderers gles
		#pragma surface surf Lambert
		#pragma target 3.0

//
//      Ported by kioku / System K
//
//      Referenced: https://code.google.com/p/aobench/
//      Let's AOBench!
//
		sampler2D _MainTex;

		struct Input {
			float2 uv_MainTex;
		};
		
		struct Ray
		{
			float3 org;
			float3 dir;
		};
		struct Sphere
		{
			float3 center;
			float radius;
		};
		struct Plane
		{
			float3 p;
			float3 n;
		};
		
		struct Intersection
		{
		    float t;
		    float3 p;     // hit point
		    float3 n;     // normal
		    int hit;
		};
		
		Sphere sphere[3];
		Plane plane;
		float aspectRatio = (800 / 600.0);
		static int seed = 0;
		
		void shpere_intersect(Sphere s, Ray ray, inout Intersection isect)
		{
		    // rs = ray.org - sphere.center
		    float3 rs = ray.org - s.center;
		    float B = dot(rs, ray.dir);
		    float C = dot(rs, rs) - (s.radius * s.radius);
		    float D = B * B - C;
		
		    if (D > 0.0)
		    {
				float t = -B - sqrt(D);
				if ( (t > 0.0) && (t < isect.t) )
				{
					isect.t = t;
					isect.hit = 1;
		
					// calculate normal.
					isect.p = ray.org + ray.dir * t;
					isect.n = normalize(isect.p - s.center);
				}
			}
		}
		void plane_intersect(Plane pl, Ray ray, inout Intersection isect)
		{
			float d = -dot(pl.p, pl.n);
			float v = dot(ray.dir, pl.n);
		
			if (abs(v) < 1.0e-6) {
				return;
			} else {
				float t = -(dot(ray.org, pl.n) + d) / v;
		
				if ( (t > 0.0) && (t < isect.t) )
				{
					isect.hit = 1.0;
					isect.t   = t;
					isect.n   = pl.n;
					isect.p = ray.org + t * ray.dir;
				}
			}
		}
	
	
		void Intersect(Ray r, inout Intersection i)
		{
			for (int c = 0; c < 3; c++)
			{
				shpere_intersect(sphere[c], r, i);
			}
			plane_intersect(plane, r, i);
		}


		
		void orthoBasis(out float3x3 basis, float3 n)
		{
			if ((n.x < 0.6) && (n.x > -0.6))
				basis[1].x = 1.0;
			else if ((n.y < 0.6) && (n.y > -0.6))
				basis[1].y = 1.0;
			else if ((n.z < 0.6) && (n.z > -0.6))
				basis[1].z = 1.0;
			else
				basis[1].x = 1.0;
		
			basis[2] = n;
			basis[0] = cross(basis[1], basis[2]);
			basis[0] = normalize(basis[0]);
		
			basis[1] = cross(basis[2], basis[0]);
			basis[1] = normalize(basis[1]);
		}
		
		float random()
		{
			seed = int(fmod(float(seed)*1364.0+626.0,509.0));
			return float(seed)/509.0;
		}

		
		float3 computeAO(inout Intersection isect)
		{
			const int ntheta = 2;
			const int nphi   = 2;
			const float eps  = 0.0001;
		
		    // Slightly move ray org towards ray dir to avoid numerical problem.
		    float3 p = isect.p + eps * isect.n;
		
		    // Calculate orthogonal basis.
		    float3x3 basis;
		    orthoBasis(basis, isect.n);
		
		    float occlusion = 0.0;
		
		    for (int j = 0; j < ntheta; j++)
		    {
				for (int i = 0; i < nphi; i++)
				{
					// Pick a random ray direction with importance sampling.
					// p = cos(theta) / 3.141592
					float r = random();
					float phi = 2.0 * 3.141592 * random();
		
					float3 ref;
					float s, c;
					sincos(phi, s, c);
					ref.x = c * sqrt(1.0 - r);
					ref.y = s * sqrt(1.0 - r);
					ref.z = sqrt(r);
		
					Ray ray;
					ray.org = p;
					// local -> global
					ray.dir = mul(ref, basis);
		
					Intersection occIsect;
					occIsect.hit = 0;
					occIsect.t = 1.0e30;
					occIsect.n = occIsect.p = float3(0, 0, 0);
					Intersect(ray, occIsect);
					occlusion += (occIsect.hit != 0);
				}
			}
		
			// [0.0, 1.0]
			occlusion = (float(ntheta * nphi) - occlusion) / float(ntheta * nphi);
			return occlusion.xxx;
		}
		

		void surf (Input IN, inout SurfaceOutput o)
		{
		
			float3 dir = normalize(float3(-IN.uv_MainTex*2.0 + float2(1.0,1.0),-1.0));
			Ray ray;
			ray.org = float3(0,0,0);
			ray.dir = dir;
			Intersection it;
			it.hit = 0;
			it.n = float3(0,0,0);
			it.p = float3(0,0,0);
			it.t = 10000.0;
			
			sphere[0].center = float3(-2.0, 0.0, -3.5);
			sphere[0].radius = 0.5;
			sphere[1].center = float3(-0.5, 0.0, -3.0);
			sphere[1].radius = 0.5;
			sphere[2].center = float3(1.0, 0.0, -2.2);
			sphere[2].radius = 0.5;
			plane.p = float3(0,-0.5, 0);
			plane.n = float3(0, 1.0, 0);
			Intersect(ray,it);
		
			seed = int(mod((dir.x+0.5) * (dir.y+0.5) * 4525434.0, 65536.0));
		
			//o.Albedo = computeAO(it);
			o.Emission = computeAO(it);
			o.Alpha = 1.0;
		}
		ENDCG
	} 
	FallBack "Diffuse"
}
