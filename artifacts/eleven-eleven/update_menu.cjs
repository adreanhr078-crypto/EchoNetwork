const fs = require('fs');
let code = fs.readFileSync('src/features/screens/MainMenuScreen.tsx', 'utf8');

code = code.replace(
  /const authStatus = useAuthStore\(\(store\) => store\.status\);/,
  `const authStatus = useAuthStore((store) => store.status);\n  const authConfigured = useAuthStore((store) => store.configured);`
);

code = code.replace(
  /const continueJourney = \(\) => \{[^}]*return;[^}]*\}\s*navigate\('psychological-state'\);\s*\};/s,
  `const continueJourney = () => {
    if (!signedIn) {
      if (import.meta.env.DEV && !authConfigured) {
        navigate('play');
        return;
      }
      setAuthOpen(true);
      return;
    }
    navigate('psychological-state');
  };`
);

fs.writeFileSync('src/features/screens/MainMenuScreen.tsx', code);
