using Flax.Build;

/// <summary>
/// Echo Network editor target build configuration.
/// </summary>
public class EchoNetworkFlaxEditorTarget : GameProjectEditorTarget
{
    /// <inheritdoc />
    public override void Init()
    {
        base.Init();

        OutputName = "EchoNetworkFlaxEditor";
        ConfigurationName = "EchoNetworkFlaxEditor";
        Modules.Add("EchoNetworkFlax");
    }
}
