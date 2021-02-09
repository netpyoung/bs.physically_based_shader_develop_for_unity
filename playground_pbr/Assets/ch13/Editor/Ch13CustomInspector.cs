using UnityEditor;

public class Ch13CustomInspector : ShaderGUI
{
    // ref: https://docs.unity3d.com/2021.1/Documentation/Manual/SL-CustomShaderGUI.html

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        MaterialProperty _EnableCookTorrance = FindProperty("_EnableCookTorrance", properties);
        MaterialProperty _Roughness = FindProperty("_Roughness", properties);

        foreach (MaterialProperty property in properties)
        {
            if (_EnableCookTorrance.floatValue != 1 && property == _Roughness)
            {

            }
            else
            {
                materialEditor.ShaderProperty(property, property.displayName);
            }
        }
    }
}
