// firebase.js
const admin = require('firebase-admin');

// 🚨 CORREÇÃO: Garante que o .env seja carregado antes de qualquer tentativa de uso.
// Tentamos carregar o .env. Se já foi carregado em server.js, este comando é inofensivo.
try {
    require('dotenv').config();
} catch (e) {
    // Apenas ignora se houver erro, pois o .env pode estar sendo carregado em outro lugar.
}


let serviceAccount;

// 1. Tenta carregar o arquivo local usando o caminho do .env (Seu ambiente de desenvolvimento)
const firebasePath = process.env.FIREBASE_ADMIN_SDK_PATH;

if (firebasePath) {
    try {
        // Tenta carregar o arquivo. É aqui que o erro ERR_INVALID_ARG_TYPE ocorria
        // se a variável não estivesse definida.
        serviceAccount = require(firebasePath);
        console.log('Firebase: Usando arquivo local serviceAccountKey.json.');
    } catch (e) {
        // Captura erro se o arquivo não for encontrado (caminho errado ou nome errado)
        console.error('Firebase: ERRO ao carregar arquivo local da chave. Verifique o caminho no .env.', e.message);
    }
} 
// 2. Tenta ler o JSON da variável de ambiente (Ambiente de deploy, como o Render)
else if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    try {
        // Converte a string JSON da variável de ambiente em um objeto JS
        serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
        console.log('Firebase: Usando variável de ambiente FIREBASE_SERVICE_ACCOUNT_JSON.');
    } catch (e) {
        console.error('Firebase: ERRO ao parsear FIREBASE_SERVICE_ACCOUNT_JSON. Verifique o formato do JSON.', e.message);
    }
} 

if (serviceAccount) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('Firebase Admin SDK inicializado.');
} else {
    console.error('Firebase: ERRO! Não foi possível inicializar o SDK (Chave não encontrada em nenhum formato).');
}

module.exports = admin;