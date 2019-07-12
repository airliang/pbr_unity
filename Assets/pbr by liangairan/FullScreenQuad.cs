using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FullScreenQuad
{
    private GameObject mScreenQuad;
    Mesh mQuadMesh;
    private Vector3[] mVertices;
    private Vector2[] mUVs;
    private int[] mTriangles;
    // Start is called before the first frame update
    public FullScreenQuad()
    {
        mVertices = new Vector3[4];
        mVertices[0] = new Vector3(-1.0f, 1.0f, 0.0f);
        mVertices[1] = new Vector3(1.0f, 1.0f, 0.0f);
        mVertices[2] = new Vector3(-1.0f, -1.0f, 0.0f);
        mVertices[3] = new Vector3(1.0f, -1.0f, 0.0f);

        mUVs = new Vector2[4];
        mUVs[0] = new Vector2(0.0f, 0.0f);
        mUVs[1] = new Vector2(1.0f, 0.0f);
        mUVs[2] = new Vector2(0.0f, 1.0f);
        mUVs[3] = new Vector2(1.0f, 1.0f);

        mTriangles = new int[6];
        mTriangles[0] = 0;
        mTriangles[1] = 1;
        mTriangles[2] = 2;
        mTriangles[3] = 1;
        mTriangles[4] = 3;
        mTriangles[5] = 2;

        mQuadMesh = new Mesh();
        mQuadMesh.vertices = mVertices;
        mQuadMesh.uv = mUVs;
        mQuadMesh.triangles = mTriangles;

        mScreenQuad = new GameObject("FullScreenQuad");
        mScreenQuad.AddComponent<MeshRenderer>();
        MeshFilter meshFilter = mScreenQuad.AddComponent<MeshFilter>();
        meshFilter.mesh = mQuadMesh;
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    public GameObject GetGameObject()
    {
        return mScreenQuad;
    }

    public void Clear()
    {
        mQuadMesh.Clear();
#if UNITY_EDITOR
        Object.DestroyImmediate(mScreenQuad);
#else
        Object.Destroy(mScreenQuad);
#endif
        mScreenQuad = null;
    }
}
