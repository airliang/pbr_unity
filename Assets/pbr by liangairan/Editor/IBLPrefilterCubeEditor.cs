using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using UnityEngine.SceneManagement;

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
            //创建一个球
            mPBRObject = GameObject.CreatePrimitive(PrimitiveType.Cube);
            mPBRObject.layer = LayerMask.NameToLayer("RenderToCubemap");
            mPBRObject.transform.position = Vector3.zero;
            mPBRObject.transform.rotation = Quaternion.identity;
        }
        if (mCameraObject == null)
        {
            mCameraObject = new GameObject("RenderToCubemap");
            mCameraObject.transform.position = mPBRObject.transform.position;
            mCameraObject.transform.rotation = Quaternion.identity;
        }

        Camera camera = mCameraObject.GetComponent<Camera>();
        if (camera == null)
        {
            camera = mCameraObject.AddComponent<Camera>();
            mCamera = camera;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = Color.black;
        }
        mCamera.targetTexture = null;
        camera.cullingMask = 1 << LayerMask.NameToLayer("RenderToCubemap");
        
        if (mPrefilterIrradianceDiffuseMaterial == null)
        {
            Shader prefilterCube = Shader.Find("liangairan/pbr/prefilterIrradianceCubemap");
            mPrefilterIrradianceDiffuseMaterial = new Material(prefilterCube);
            //camera.SetReplacementShader(prefilterCube, "RenderType");
            mPrefilterIrradianceDiffuseMaterial.SetTexture("_Cube", mEnvironmentMap);
        }

        
        mPBRObject.GetComponent<Renderer>().sharedMaterial = mPrefilterIrradianceDiffuseMaterial;


        Cubemap irradianceDiffuseMap = (Cubemap)AssetDatabase.LoadAssetAtPath(mOutputPath + "irradianceDiffuseMap.cubemap", typeof(Cubemap));
        bool bNewAsset = false;
        if (irradianceDiffuseMap == null)
        {
            irradianceDiffuseMap = new Cubemap(mOutputIrradianceDiffuseMapSize, TextureFormat.RGBAHalf, false);
            bNewAsset = true;
        }
        camera.RenderToCubemap(irradianceDiffuseMap, 63);
        irradianceDiffuseMap.Apply();
        //for (int f = 0; f < 6; ++f)
        //{
        //    irradianceDiffuseMap.SetPixels(mIrradianceMapAsset.GetPixels((CubemapFace)f), (CubemapFace)f);
        //}

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
        //if (mCubeMapSpecular == null)
        //{
        //    Debug.LogError("cubemapspecular is null!");
        //    return;
        //}

        List<Cubemap> lstCubemaps = new List<Cubemap>(); 

        if (mPBRObject == null)
        {
            //创建一个球
            mPBRObject = GameObject.CreatePrimitive(PrimitiveType.Cube);
            mPBRObject.layer = LayerMask.NameToLayer("RenderToCubemap");
            mPBRObject.transform.position = Vector3.zero;
            mPBRObject.transform.rotation = Quaternion.identity;
        }
        if (mCameraObject == null)
        {
            mCameraObject = new GameObject("RenderToCubemap");
            mCameraObject.transform.position = mPBRObject.transform.position;
            mCameraObject.transform.rotation = Quaternion.identity;
        }

        Camera camera = mCameraObject.GetComponent<Camera>();
        if (camera == null)
        {
            camera = mCameraObject.AddComponent<Camera>();
            mCamera = camera;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = Color.black;
        }
        //mCamera.targetTexture = mCubeMapSpecular;
        camera.cullingMask = 1 << LayerMask.NameToLayer("RenderToCubemap");

        if (mPrefilterEnvSpecularMaterial == null)
        {
            Shader prefilterCube = Shader.Find("liangairan/pbr/prefilterSpecularMap");
            mPrefilterEnvSpecularMaterial = new Material(prefilterCube);
            //camera.SetReplacementShader(prefilterCube, "RenderType");
            mPrefilterEnvSpecularMaterial.SetTexture("_Cube", mEnvironmentMap);
        }

        mPBRObject.GetComponent<Renderer>().sharedMaterial = mPrefilterEnvSpecularMaterial;

        int cubeMapSize = mOutputSpecularMapSize;
        int mipmapsNum = (int)Mathf.Log(cubeMapSize, 2);

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
            quadObj.layer = LayerMask.NameToLayer("RenderToCubemap");
            quadObj.transform.position = mCamera.transform.position + mCamera.transform.forward * 5.0f;
        }

        mCamera.targetTexture = mBRDFMap;
        mCamera.Render();
        RenderTexture.active = mBRDFMap;
        Texture2D brdfLUT = new Texture2D(mBRDFMap.width, mBRDFMap.height, TextureFormat.RGBAFloat, false);
        brdfLUT.ReadPixels(new Rect(0, 0, mBRDFMap.width, mBRDFMap.height), 0, 0);
        brdfLUT.Apply();
        byte[] bytes = brdfLUT.EncodeToPNG();

        File.WriteAllBytes(mOutputPath + "brdfLUT.png", bytes);
        DestroyImmediate(brdfLUT);
        brdfLUT = null;
        mCamera.targetTexture = null;
        DestroyImmediate(mBRDFMap);
        AssetDatabase.Refresh();

        TextureImporter textureImporter = AssetImporter.GetAtPath(mOutputPath + "brdfLUT.png") as TextureImporter;
        textureImporter.textureType = TextureImporterType.Default;
        textureImporter.mipmapEnabled = false;
        textureImporter.sRGBTexture = true;
        textureImporter.filterMode = FilterMode.Bilinear;
        textureImporter.wrapMode = TextureWrapMode.Clamp;
        textureImporter.maxTextureSize = Mathf.Max(512, 512);
        AssetDatabase.ImportAsset(mOutputPath + "brdfLUT.png", ImportAssetOptions.ForceUpdate | ImportAssetOptions.ForceSynchronousImport);
    }

    private void OnGUI()
    {
        //EditorGUILayout.BeginHorizontal();
        //GUILayout.Label("渲染物：");
        //mPBRObject = EditorGUILayout.ObjectField(mPBRObject, typeof(Transform), true) as Transform;
        //EditorGUILayout.EndHorizontal();

        
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
    }
}

#endif
