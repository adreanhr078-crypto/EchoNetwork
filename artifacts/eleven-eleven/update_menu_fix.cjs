const fs = require('fs');
let code = fs.readFileSync('src/features/screens/MainMenuScreen.tsx', 'utf8');

code = code.replace('  const authConfigured = useAuthStore((store) => store.configured);\n  const authConfigured = useAuthStore((store) => store.configured);', '  const authConfigured = useAuthStore((store) => store.configured);');

fs.writeFileSync('src/features/screens/MainMenuScreen.tsx', code);
