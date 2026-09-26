using Flax.Build;
using Flax.Build.NativeCpp;

/// <summary>
/// Echo Network game module build configuration.
/// </summary>
public class EchoNetworkFlax : GameProjectChildModule
{
    /// <inheritdoc />
    public override void Setup(BuildOptions options)
    {
        base.Setup(options);

        BuildNativeCode = false;
    }
}
