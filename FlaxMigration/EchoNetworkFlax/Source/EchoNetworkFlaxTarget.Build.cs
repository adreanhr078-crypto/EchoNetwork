using Flax.Build;

/// <summary>
/// Echo Network game target build configuration.
/// </summary>
public class EchoNetworkFlaxTarget : GameProjectTarget
{
    /// <inheritdoc />
    public override void Init()
    {
        base.Init();

        OutputName = "EchoNetworkFlax";
        ConfigurationName = "EchoNetworkFlax";
        Modules.Add("EchoNetworkFlax");
    }
}
