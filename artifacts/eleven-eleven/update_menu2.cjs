const fs = require('fs');
let code = fs.readFileSync('src/features/screens/MainMenuScreen.tsx', 'utf8');

code = code.replace(
  'const authStatus = useAuthStore((store) => store.status);',
  'const authStatus = useAuthStore((store) => store.status);\n  const authConfigured = useAuthStore((store) => store.configured);'
);

code = code.replace(
  '  const continueJourney = () => {\n    if (!signedIn) {\n      setAuthOpen(true);\n      return;\n    }\n    // Signing in should first return the player to the central mission hub.\n    // The Manhwa opens only from an explicit objective inside that hub.\n    navigate(\'psychological-state\');\n  };',
  '  const continueJourney = () => {\n    if (!signedIn) {\n      if (import.meta.env.DEV && !authConfigured) {\n        navigate(\'play\');\n        return;\n      }\n      setAuthOpen(true);\n      return;\n    }\n    navigate(\'psychological-state\');\n  };'
);

fs.writeFileSync('src/features/screens/MainMenuScreen.tsx', code);
