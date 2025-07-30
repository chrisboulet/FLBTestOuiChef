#!/usr/bin/env node
const readline = require('readline');
const fs = require('fs');
const path = require('path');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(prompt) {
  return new Promise((resolve) => {
    rl.question(prompt, resolve);
  });
}

function questionHidden(prompt) {
  return new Promise((resolve) => {
    process.stdout.write(prompt);
    process.stdin.setRawMode(true);
    process.stdin.resume();
    
    let password = '';
    process.stdin.on('data', function(ch) {
      ch = ch.toString('utf8');
      
      switch (ch) {
        case '\n':
        case '\r':
          process.stdin.setRawMode(false);
          process.stdin.pause();
          process.stdout.write('\n');
          resolve(password);
          break;
        case '\u0003': // Ctrl-C
          process.exit();
          break;
        case '\u0008': // Backspace
        case '\u007f': // Delete
          if (password.length > 0) {
            password = password.slice(0, -1);
            process.stdout.write('\b \b');
          }
          break;
        default:
          if (ch.charCodeAt(0) >= 32) {
            password += ch;
            process.stdout.write('*');
          }
          break;
      }
    });
  });
}

async function setupCredentials() {
  console.log('🔧 Configuration des identifiants FLB Solutions');
  console.log('═══════════════════════════════════════════════\n');
  
  try {
    // Demander les informations
    const email = await question('📧 Email de connexion: ');
    const dadhriNumber = await question('🏷️  Numéro Dadhri: ');
    const password = await questionHidden('🔒 Mot de passe: ');
    
    // Créer le fichier .env
    const envContent = `# Configuration FLB Solutions Tests
FLB_TEST_EMAIL=${email}
FLB_TEST_PASSWORD=${password}
FLB_TEST_DADHRI=${dadhriNumber}

# Configuration Playwright
PLAYWRIGHT_BROWSERS_PATH=./browsers
`;

    fs.writeFileSync('.env', envContent);
    
    console.log('\n✅ Fichier .env créé avec succès!');
    console.log('\n📋 Informations sauvegardées:');
    console.log(`   📧 Email: ${email}`);
    console.log(`   🏷️  Dadhri: ${dadhriNumber}`);
    console.log('   🔒 Mot de passe: ********\n');
    
    console.log('🚀 Vous pouvez maintenant lancer les tests:');
    console.log('   npm run test              # Tests de base');
    console.log('   npm run test:smoke        # Tests smoke uniquement');
    console.log('   npm run test:auth         # Tests authentifiés');
    console.log('   npm run test:all-browsers # Multi-navigateurs\n');
    
  } catch (error) {
    console.error('❌ Erreur lors de la configuration:', error.message);
    process.exit(1);
  } finally {
    rl.close();
  }
}

setupCredentials();