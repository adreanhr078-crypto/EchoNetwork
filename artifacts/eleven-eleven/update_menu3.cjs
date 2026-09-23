const fs = require('fs');
let code = fs.readFileSync('src/features/screens/MainMenuScreen.tsx', 'utf8');

if (!code.includes('authConfigured')) {
  code = code.replace(
    'const authStatus = useAuthStore((store) => store.status);',
    'const authStatus = useAuthStore((store) => store.status);\n  const authConfigured = useAuthStore((store) => store.configured);'
  );
}

code = code.replace(/const continueJourney = \(\) => \{[\s\S]*?navigate\('psychological-state'\);\s*\};/,
  'const continueJourney = () => {\n' +
  '  if (!signedIn) {\n' +
  '    if (import.meta.env.DEV && !authConfigured) {\n' +
  '      navigate(\'play\');\n' +
  '      return;\n' +
  '    }\n' +
  '    setAuthOpen(true);\n' +
  '    return;\n' +
  '  }\n' +
  '  navigate(\'psychological-state\');\n' +
  '};'
);

fs.writeFileSync('src/features/screens/MainMenuScreen.tsx', code);
