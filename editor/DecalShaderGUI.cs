using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;

namespace ErrorMdl.Decals
{
    public class DecalShaderGUI : ShaderGUI
    {
        static List<ParticleSystemVertexStream> vertexStreams = new List<ParticleSystemVertexStream>() 
        {
            ParticleSystemVertexStream.Position,
            ParticleSystemVertexStream.Color,
            ParticleSystemVertexStream.Center,
            ParticleSystemVertexStream.SizeXYZ,
            ParticleSystemVertexStream.AnimFrame
        };
        bool showInfo = false;
		static GUIContent Hint = new GUIContent(
            "The Particle system must have these properties:\n" +
            "    Scaling Mode: Local\n" +
            "    Render Mode : Mesh\n" +
            "    Render Alignment : World\n" +
            "    Enable Mesh GPU Instancing : True\n" +
            "This is designed to be used with the default unity cube as the particle mesh\n"+
            "Set your particle systems custom vertex streams to\n" +
            "    Position POSITION.xyz\n" +
            "    Center TEXCOORD0.xyz\n" +
            "    Size TEXCOORD0.w xy\n" +
            "    AnimFrame TEXCOORD1.z\n" +
            "    Color COLOR.xyzw\n" +
            "Needs a real time directional light with shadows in the scene/on the avatar to function. " +
			"Set the directional light's culling mask to only the 'Ignore Raycast' layer to make it not light anything or cause performance issues. " +
			"\nRemember to turn on light probes in the renderer tab when using lighting. " +
			"Set the particle system scaling mode to local, and ensure the system's transform has a scale of 1 on all axes for correct scaling of the decal\n"
			);

        enum LocalBlendMode : int
        {
            Transparent = 0,
            Additive = 1,
            AlphaPremultiplied = 2,
            Multiplicative = 3
        }

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            GUIStyle FoldoutStyle = EditorStyles.foldout;
            FoldoutStyle.richText = true;
            showInfo = EditorGUILayout.Foldout(showInfo, "<b>Setup Info</b>");
            if (showInfo)
            {
                GUIStyle textStyle = EditorStyles.label;
                textStyle.wordWrap = true;
                EditorGUILayout.LabelField(Hint, textStyle);
            }

            if (GUILayout.Button("Set Required Properties On Selected"))
            {
                Mesh cube = Resources.GetBuiltinResource<Mesh>("Cube.fbx");
                ParticleSystemRenderer[] systems = GetSelectedParticles();
                for (int i = 0; i < systems.Length; i++) 
                {
                    systems[i].SetActiveVertexStreams(vertexStreams);
                    systems[i].alignment = ParticleSystemRenderSpace.World;
                    systems[i].renderMode = ParticleSystemRenderMode.Mesh;
                    systems[i].mesh = cube;
                    ParticleSystem ps = systems[i].GetComponent<ParticleSystem>();
                    ParticleSystem.MainModule mm = ps.main;
                    mm.scalingMode = ParticleSystemScalingMode.Local;
                }

            }

            int numProps = properties.Length;
            MaterialProperty srcBlend = null;
            MaterialProperty dstBlend = null;
            MaterialProperty blendMode = null;
            for (int i = 0; i < numProps; i++)
            {
                if (properties[i].name == "_SrcBlend")
                {
                    srcBlend = properties[i];
                }
                else if (properties[i].name == "_DstBlend")
                {
                    dstBlend = properties[i];
                }
                else if (properties[i].name == "_Blend")
                {
                    blendMode = properties[i];
                }
            }

            if (srcBlend != null && dstBlend != null && blendMode != null)
            {
                EditorGUI.BeginChangeCheck();
                LocalBlendMode blendVal = (LocalBlendMode)blendMode.floatValue;
                blendVal = (LocalBlendMode)EditorGUILayout.EnumPopup("Blend Mode", blendVal);
                if (EditorGUI.EndChangeCheck())
                {
                    blendMode.floatValue = (float)blendVal;
                    switch (blendVal)
                    {
                        case LocalBlendMode.Transparent:
                            srcBlend.floatValue = (float)BlendMode.SrcAlpha;
                            dstBlend.floatValue = (float)BlendMode.OneMinusSrcAlpha;
                            break;
                        case LocalBlendMode.Additive:
                            srcBlend.floatValue = (float)BlendMode.One;
                            dstBlend.floatValue = (float)BlendMode.One;
                            break;
                        case LocalBlendMode.AlphaPremultiplied:
                            srcBlend.floatValue = (float)BlendMode.One;
                            dstBlend.floatValue = (float)BlendMode.OneMinusSrcAlpha;
                            break;
                        case LocalBlendMode.Multiplicative:
                            srcBlend.floatValue = (float)BlendMode.DstColor;
                            dstBlend.floatValue = (float)BlendMode.Zero;
                            break;
                    }
                }
            }

            base.OnGUI(materialEditor, properties);
          
        }

        ParticleSystemRenderer[] GetSelectedParticles()
        {
            GameObject[] selection = Selection.gameObjects;
            ParticleSystemRenderer[] particleSystems = new ParticleSystemRenderer[selection.Length];
            bool allParticles = false;
            if (selection != null && selection.Length > 0)
            {
                allParticles = true;
                int numSelection = selection.Length;
                for (int i = 0; i < numSelection; i++)
                {
                    ParticleSystemRenderer system = selection[i].GetComponent<ParticleSystemRenderer>();
                    if (system == null)
                    {
                        allParticles = false;
                        break;
                    }
                    particleSystems[i] = system;
                }
            }
            else
            {
                Debug.LogError("No selected scene objects, can't set vertex streams!");
            }

            if (allParticles)
            {
                return particleSystems;
            }
            else
            {
                Debug.LogError("Not all selected scene objects have particle systems, can't set vertex streams!");
                return new ParticleSystemRenderer[0];
            }
        }
    }
}
