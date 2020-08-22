using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using UnityEngine.SceneManagement;
using UnityEngine.Rendering;

#if UNITY_EDITOR

public class IBLPrefilterCubeEditor : EditorWindow {
    static IBLPrefilterCubeEditor _windowInstance;

    Material mPrefilterIrradianceDiffuseMaterial;
    Material mPrefilterEnvSpecularMaterial;
    Material mRenderToBRDFMaterial;
    Camera mCamera;
    //RenderTexture mCubeMap;
    //RenderTexture mBRDFMap;
    //RenderTexture mCubeMapSpecular;
    //Cubemap mIrradianceMapAsset;
    Cubemap mSpecularIBLMap;
    Cubemap mEnvironmentMap;
    GameObject mPBRObject = null;
    Texture mNormalMap;
    GameObject mCameraObject;
    int mSourceEnvironmentMapSize = 128;
    int mOutputSpecularMapSize = 128;
    int mOutputIrradianceDiffuseMapSize = 64;
    string mOutputPath;
    bool genBRDFLutByGPU = false;
    ComputeShader brdfCompute = null;
    //ComputeShader prefilterIrradianceCompute = null;

    //GameObject mQuad;
    FullScreenQuad mQuad;

    [MenuItem("Tools/Prefilter IBL Maps", false, 0)]
    static void ShowIBLWindow()
    {
        if (_windowInstance == null)
        {
            _windowInstance = EditorWindow.GetWindow(typeof(IBLPrefilterCubeEditor), true, "ibl cubemap editor") as IBLPrefilterCubeEditor;
            //SceneView.onSceneGUIDelegate += OnSceneGUI;
        }
    }

    void PrefilterEnvMapIrradiance()
    {
        if (mPBRObject == null)
        {
            //创建一个cube
            mPBRObject = GameObject.CreatePrimitive(PrimitiveType.Cube);
            mPBRObject.AddComponent<Camera>();
            mPBRObject.layer = LayerMask.NameToLayer("RenderToCubemap");
            mPBRObject.transform.position = Vector3.zero;
            mPBRObject.transform.rotation = Quaternion.identity;
        }
        //if (mCameraObject == null)
        //{
        //    mCameraObject = new GameObject("RenderToCubemap");
        //    mCameraObject.transform.position = mPBRObject.transform.position;
        //    mCameraObject.transform.rotation = Quaternion.identity;
        //}

        Camera camera = mPBRObject.GetComponent<Camera>();
        if (camera != null)
        {
            //camera = mCameraObject.AddComponent<Camera>();
            mCamera = camera;
        }
        else
        {
            mCamera = mPBRObject.AddComponent<Camera>();
        }

        mCamera.clearFlags = CameraClearFlags.SolidColor;
        mCamera.backgroundColor = Color.black;
        mCamera.targetTexture = null;
        mCamera.cullingMask = 1 << LayerMask.NameToLayer("RenderToCubemap");


        if (mPrefilterIrradianceDiffuseMaterial == null)
        {
            Shader prefilterCube = Shader.Find("liangairan/pbr/prefilterIrradianceCubemap");
            mPrefilterIrradianceDiffuseMaterial = new Material(prefilterCube);
            mPrefilterIrradianceDiffuseMaterial.SetTexture("_Cube", mEnvironmentMap);
        }

        mPBRObject.GetComponent<Renderer>().sharedMaterial = mPrefilterIrradianceDiffuseMaterial;


        Cubemap irradianceDiffuseMap = (Cubemap)AssetDatabase.LoadAssetAtPath(mOutputPath + "irradianceDiffuseMap.cubemap", typeof(Cubemap));
        bool bNewAsset = false;
        if (irradianceDiffuseMap == null)
        {
            irradianceDiffuseMap = new Cubemap(mOutputIrradianceDiffuseMapSize, TextureFormat.RGBAHalf, true);

            bNewAsset = true;
        }
        camera.RenderToCubemap(irradianceDiffuseMap, 63);
        irradianceDiffuseMap.Apply();


        if (bNewAsset)
            AssetDatabase.CreateAsset(irradianceDiffuseMap, mOutputPath + "irradianceDiffuseMap.cubemap");
        else
        {
            AssetDatabase.SaveAssets();
        }

        irradianceDiffuseMap = null;
        //DestroyImmediate(irradianceDiffuseMap);
    }

    void PrefilterEnvMapSpecular()
    {
        List<Cubemap> lstCubemaps = new List<Cubemap>(); 

        if (mPBRObject == null)
        {
            //创建一个球
            mPBRObject = GameObject.CreatePrimitive(PrimitiveType.Cube);
            mPBRObject.layer = LayerMask.NameToLayer("RenderToCubemap");
            mPBRObject.transform.position = Vector3.zero;
            mPBRObject.transform.rotation = Quaternion.identity;
        }
        //if (mCameraObject == null)
        //{
        //    mCameraObject = new GameObject("RenderToCubemap");
        //    mCameraObject.transform.position = mPBRObject.transform.position;
        //    mCameraObject.transform.rotation = Quaternion.identity;
        //}

        Camera camera = mPBRObject.GetComponent<Camera>();
        if (camera != null)
        {
            //camera = mCameraObject.AddComponent<Camera>();
            mCamera = camera;
        }
        else
        {
            mCamera = mPBRObject.AddComponent<Camera>();
        }
 
        mCamera.clearFlags = CameraClearFlags.SolidColor;
        mCamera.backgroundColor = Color.black;
        mCamera.cullingMask = 1 << LayerMask.NameToLayer("RenderToCubemap");
        mCamera.targetTexture = null;

        if (mPrefilterEnvSpecularMaterial == null)
        {
            Shader prefilterCube = Shader.Find("liangairan/pbr/prefilterSpecularMap");
            mPrefilterEnvSpecularMaterial = new Material(prefilterCube);
            //camera.SetReplacementShader(prefilterCube, "RenderType");
            mPrefilterEnvSpecularMaterial.SetTexture("_Cube", mEnvironmentMap);
        }

        mPBRObject.GetComponent<Renderer>().sharedMaterial = mPrefilterEnvSpecularMaterial;

        int cubeMapSize = mOutputSpecularMapSize;
        int mipmapsNum = (int)Mathf.Log(cubeMapSize, 2) + 1;

        for (int i = 0; i < mipmapsNum; ++i)
        {
            int width = cubeMapSize >> i;
            Cubemap cubeMap = new Cubemap(width, TextureFormat.RGBAHalf, false);
            float roughness = i / (float)(mipmapsNum - 1);
            mPrefilterEnvSpecularMaterial.SetFloat("_roughness", roughness);

            camera.RenderToCubemap(cubeMap, 63);
            lstCubemaps.Add(cubeMap);
            //AssetDatabase.CreateAsset(lstCubemaps[i], "Assets/pbr by liangairan/specularPrefilter_" + i + ".cubemap");
        }

        //camera.targetTexture = mCubeMapSpecular;
        //camera.RenderToCubemap(mCubeMapSpecular, 63);
        //camera.targetTexture = null;

        Cubemap specularPrefilterMap = (Cubemap)AssetDatabase.LoadAssetAtPath(mOutputPath + "specularPrefilter.cubemap", typeof(Cubemap));
        bool bNewAsset = false;
        if (specularPrefilterMap == null)
        {
            specularPrefilterMap = new Cubemap(cubeMapSize, TextureFormat.RGBAHalf, true);
            bNewAsset = true;
        }

        for (int i = 0; i < lstCubemaps.Count; ++i)
        {
            Cubemap mipmap = lstCubemaps[i];
            for (int j = 0; j < 6; ++j)
            {
                specularPrefilterMap.SetPixels(mipmap.GetPixels((CubemapFace)j), (CubemapFace)j, i);
            }
        }

        if (bNewAsset)
        {
            AssetDatabase.CreateAsset(specularPrefilterMap, mOutputPath + "specularPrefilter.cubemap");
        }

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        //TextureImporter textureImporter = AssetImporter.GetAtPath(mOutputPath + "specularPrefilter.cubemap") as TextureImporter;
        //textureImporter.textureType = TextureImporterType.Default;
        //textureImporter.textureShape = TextureImporterShape.TextureCube;
        //textureImporter.mipmapEnabled = true;
        //textureImporter.sRGBTexture = true;
        //AssetDatabase.ImportAsset(mOutputPath + "specularPrefilter.cubemap", ImportAssetOptions.ForceUpdate | ImportAssetOptions.ForceSynchronousImport);

        for (int i = 0; i < lstCubemaps.Count; ++i)
        {
            DestroyImmediate(lstCubemaps[i]);
        }
        lstCubemaps.Clear();
    }

    void RenderToBRDFMap()
    {
        if (File.Exists(mOutputPath + "brdfLUT.png"))
        {
            return;
        }

        Texture2D brdfLUT = null;
        if (genBRDFLutByGPU)
        {
            brdfLUT = CreateBRDFLutByCPU();
        }
        else
        {
            if (brdfCompute != null)
                brdfLUT = CreateBRDFLutByComputeShader();
            /*
            RenderTexture mBRDFMap = new RenderTexture(512, 512, 0, RenderTextureFormat.ARGBFloat);


            if (mRenderToBRDFMaterial == null)
            {
                Shader shader = Shader.Find("liangairan/pbr/brdf_lut");
                mRenderToBRDFMaterial = new Material(shader);
            }

            if (mQuad == null)
            {
                mQuad = new FullScreenQuad();
                GameObject quadObj = mQuad.GetGameObject();
                quadObj.GetComponent<MeshRenderer>().sharedMaterial = mRenderToBRDFMaterial;
                //quadObj.layer = LayerMask.NameToLayer("RenderToCubemap");
                quadObj.transform.position = mCamera.transform.position + mCamera.transform.forward * 5.0f;
            }
            //mCamera.cullingMask = 1 << LayerMask.NameToLayer("RenderToCubemap");
            mCamera.targetTexture = mBRDFMap;
            mCamera.Render();
            RenderTexture.active = mBRDFMap;
            brdfLUT = new Texture2D(mBRDFMap.width, mBRDFMap.height, TextureFormat.ARGB32, false);
            brdfLUT.ReadPixels(new Rect(0, 0, mBRDFMap.width, mBRDFMap.height), 0, 0);
            brdfLUT.Apply();

            mCamera.targetTexture = null;
            DestroyImmediate(mBRDFMap);
            */
        }
        
        
        byte[] bytes = brdfLUT.EncodeToPNG();

        File.WriteAllBytes(mOutputPath + "brdfLUT.png", bytes);
        DestroyImmediate(brdfLUT);
        brdfLUT = null;
        
        
        AssetDatabase.Refresh();

        TextureImporter textureImporter = AssetImporter.GetAtPath(mOutputPath + "brdfLUT.png") as TextureImporter;
        textureImporter.textureType = TextureImporterType.Default;
        textureImporter.mipmapEnabled = false;
        if (PlayerSettings.colorSpace == ColorSpace.Linear)
            textureImporter.sRGBTexture = false;
        else
            textureImporter.sRGBTexture = true;
        textureImporter.filterMode = FilterMode.Bilinear;
        textureImporter.wrapMode = TextureWrapMode.Clamp;
        textureImporter.maxTextureSize = Mathf.Max(512, 512);
        AssetDatabase.ImportAsset(mOutputPath + "brdfLUT.png", ImportAssetOptions.ForceUpdate | ImportAssetOptions.ForceSynchronousImport);
    }

    private void OnGUI()
    {
        EditorGUILayout.BeginHorizontal();
        GUILayout.Label("output irradiance map size:");
        mOutputIrradianceDiffuseMapSize = EditorGUILayout.IntField(mOutputIrradianceDiffuseMapSize);
        EditorGUILayout.EndHorizontal();

        
        EditorGUILayout.BeginHorizontal();
        GUILayout.Label("output specular cubemap size：");
        mOutputSpecularMapSize = EditorGUILayout.IntField(mOutputSpecularMapSize);
        EditorGUILayout.EndHorizontal();

        EditorGUILayout.BeginHorizontal();
        GUILayout.Label("enviroment map：");
        mEnvironmentMap = EditorGUILayout.ObjectField(mEnvironmentMap, typeof(Cubemap), true) as Cubemap;
        if (mEnvironmentMap != null)
        {
            mSourceEnvironmentMapSize = mEnvironmentMap.width;
        }
        EditorGUILayout.EndHorizontal();

        //EditorGUILayout.BeginHorizontal();
        //GUILayout.Label("prefliter specular map：");
        //mCubeMapSpecular = EditorGUILayout.ObjectField(mCubeMapSpecular, typeof(RenderTexture), true) as RenderTexture;
        //EditorGUILayout.EndHorizontal();

        EditorGUILayout.BeginHorizontal();
        GUILayout.Label("current scene path：");
        EditorGUILayout.EndHorizontal();
        Scene scene = SceneManager.GetActiveScene();
        mOutputPath = scene.path;
        int lastSlash = mOutputPath.LastIndexOf("/");
        if (lastSlash >= 0)
        {
            mOutputPath = mOutputPath.Substring(0, lastSlash + 1);
        }
        EditorGUILayout.BeginHorizontal();
        mOutputPath = EditorGUILayout.TextField(mOutputPath);
        
        EditorGUILayout.EndHorizontal();

        EditorGUILayout.BeginHorizontal();
        GUILayout.Label("brdflut create compute shader：");
        brdfCompute = EditorGUILayout.ObjectField(brdfCompute, typeof(ComputeShader), true) as ComputeShader;

        EditorGUILayout.EndHorizontal();

        EditorGUILayout.BeginHorizontal();
        genBRDFLutByGPU = EditorGUILayout.Toggle("gen brdflut by CPU?", genBRDFLutByGPU);
        EditorGUILayout.EndHorizontal();

        EditorGUILayout.BeginHorizontal();
        //GUILayout.Label("Render to cubemap");
        if (GUILayout.Button("Prefilter cubemap"))
        {
            PrefilterEnvMapIrradiance();
            PrefilterEnvMapSpecular();
            RenderToBRDFMap();
        }
        EditorGUILayout.EndHorizontal();

    }

    private void OnDestroy()
    {
        //AssetDatabase.CreateAsset(mIrradianceMapAsset, "Assets/test/IrradianceMap.cubemap");
        //AssetDatabase.SaveAssets();
        if (mPBRObject != null)
        {
            GameObject.DestroyImmediate(mPBRObject);
            mPBRObject = null;
        }
        if (mCamera != null)
        {
            mCamera.targetTexture = null;
        }

        if (mQuad != null)
        {
            mQuad.Clear();
            mQuad = null;
        }

        if (mCameraObject != null)
        {
            Object.DestroyImmediate(mCameraObject);
            mCameraObject = null;
        }
        mCamera = null;

        if (mPrefilterIrradianceDiffuseMaterial != null)
        {
            Object.DestroyImmediate(mPrefilterIrradianceDiffuseMaterial);
            mPrefilterIrradianceDiffuseMaterial = null;
        }

        if (mPrefilterEnvSpecularMaterial != null)
        {
            DestroyImmediate(mPrefilterEnvSpecularMaterial);
            mPrefilterEnvSpecularMaterial = null;
        }

        if (mRenderToBRDFMaterial != null)
        {
            Object.DestroyImmediate(mRenderToBRDFMaterial);
            mRenderToBRDFMaterial = null;
        }

        if (brdfCompute != null)
        {
            brdfCompute = null;
        }
    }


    float RadicalInverse_VdC(uint bits)
    {
        bits = (bits << 16) | (bits >> 16);
        bits = ((bits & 0x55555555) << 1) | ((bits & 0xAAAAAAAAu) >> 1);
        bits = ((bits & 0x33333333u) << 2) | ((bits & 0xCCCCCCCCu) >> 2);
        bits = ((bits & 0x0F0F0F0Fu) << 4) | ((bits & 0xF0F0F0F0u) >> 4);
        bits = ((bits & 0x00FF00FFu) << 8) | ((bits & 0xFF00FF00u) >> 8);
        return (float)bits * 2.3283064365386963e-10f; // / 0x100000000
    }
    // ----------------------------------------------------------------------------
    Vector2 Hammersley(uint i, uint N)
    {
        return new Vector2(i / (float)N, RadicalInverse_VdC(i));
    }

    Vector3 ImportanceSampleGGX(Vector2 Xi, Vector3 N, float roughness)
    {
        float a = roughness * roughness;

        float phi = 2.0f * Mathf.PI * Xi.x;
        float cosTheta = Mathf.Sqrt((1.0f - Xi.y) / (1.0f + (a * a - 1.0f) * Xi.y));
        float sinTheta = Mathf.Sqrt(1.0f - cosTheta * cosTheta);

        // from spherical coordinates to cartesian coordinates - halfway vector
        Vector3 H;
        H.x = Mathf.Cos(phi) * sinTheta;
        H.y = Mathf.Sin(phi) * sinTheta;
        H.z = cosTheta;

        // from tangent-space H vector to world-space sample vector
        Vector3 up = Mathf.Abs(N.z) < 0.999 ? new Vector3(0.0f, 0.0f, 1.0f) : new Vector3(1.0f, 0.0f, 0.0f);
        Vector3 tangent = Vector3.Normalize(Vector3.Cross(up, N));
        Vector3 bitangent = Vector3.Cross(N, tangent);

        Vector3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
        return Vector3.Normalize(sampleVec);
    }
    // ----------------------------------------------------------------------------
    float GeometrySchlickGGX(float NdotV, float roughness)
    {
        // note that we use a different k for IBL
        float a = roughness;
        float k = (a * a) / 2.0f;

        float nom = NdotV;
        float denom = NdotV * (1.0f - k) + k;

        return nom / denom;
    }
    // ----------------------------------------------------------------------------
    float GeometrySmith(Vector3 N, Vector3 V, Vector3 L, float roughness)
    {
        float NdotV = Mathf.Max(Vector3.Dot(N, V), 0);
        float NdotL = Mathf.Max(Vector3.Dot(N, L), 0);
        float ggx2 = GeometrySchlickGGX(NdotV, roughness);
        float ggx1 = GeometrySchlickGGX(NdotL, roughness);

        return ggx1 * ggx2;
    }

    Vector2 IntegrateBRDF(float NdotV, float roughness)
    {
        Vector3 V;
        V.x = Mathf.Sqrt(1.0f - NdotV * NdotV);
        V.y = 0.0f;
        V.z = NdotV;

        float A = 0.0f;
        float B = 0.0f;

        Vector3 N = Vector3.forward;

        const uint SAMPLE_COUNT = 1024u;
        float invSampleCount = 1.0f / SAMPLE_COUNT;
        for (uint i = 0u; i < SAMPLE_COUNT; ++i)
        {
            // generates a sample vector that's biased towards the
            // preferred alignment direction (importance sampling).
            Vector2 Xi = Hammersley(i, SAMPLE_COUNT);
            Vector3 H = ImportanceSampleGGX(Xi, N, roughness);
            Vector3 L = Vector3.Normalize(2.0f * Vector3.Dot(V, H) * H - V);

            float NdotL = Mathf.Max(L.z, 0.0f);
            float NdotH = Mathf.Max(H.z, 0.0f);
            float VdotH = Mathf.Max(Vector3.Dot(V, H), 0.0f);

            if (NdotL > 0.0)
            {
                float G = GeometrySmith(N, V, L, roughness);
                float G_Vis = (G * VdotH) / (NdotH * NdotV);
                float Fc = Mathf.Pow(1.0f - VdotH, 5.0f);

                A += (1.0f - Fc) * G_Vis;
                B += Fc * G_Vis;
            }
        }
        A *= invSampleCount;
        B *= invSampleCount;
        return new Vector2(A, B);
    }

    private Texture2D CreateBRDFLutByCPU()
    {
        Texture2D BRDFMap = new Texture2D(512, 512, TextureFormat.RGBA32, false);

        for (int i = 0; i < 512; ++i)
        {
            for (int j = 0; j < 512; ++j)
            {
                Vector2 color = IntegrateBRDF((float)j / 512.0f, (float)i / 512.0f);
                BRDFMap.SetPixel(j, i, new Color(color.x, color.y, 0));
            }
        }

        return BRDFMap;
    }

    private Texture2D CreateBRDFLutByComputeShader()
    {
        int createBrdf = brdfCompute.FindKernel("CreateBRDFLut");
        brdfCompute.SetInt("BRDFMapSize", 512);
        RenderTexture BRDFLut = new RenderTexture(512, 512, 0, RenderTextureFormat.ARGBFloat);
        BRDFLut.enableRandomWrite = true;
        BRDFLut.Create();
        brdfCompute.SetTexture(createBrdf, "BRDFLut", BRDFLut);

        brdfCompute.Dispatch(createBrdf, 512 / 8, 512 / 8, 1);

        Texture2D output = new Texture2D(512, 512, TextureFormat.RGBA32, false);
        RenderTexture.active = BRDFLut;
        output.ReadPixels(new Rect(0, 0, 512, 512), 0, 0);

        DestroyImmediate(BRDFLut);
        return output;
    }
}

#endif
