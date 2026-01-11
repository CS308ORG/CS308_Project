const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// Read the image file
const imagePath = path.join(process.env.HOME, 'Downloads', 'all-is-here-transparent-removebg-preview.png');

if (!fs.existsSync(imagePath)) {
    console.error('❌ Logo dosyası bulunamadı:', imagePath);
    process.exit(1);
}

console.log('📸 Logo dosyası okunuyor...');
const imageBuffer = fs.readFileSync(imagePath);
const base64Data = imageBuffer.toString('base64');

// Detect MIME type
const ext = path.extname(imagePath).toLowerCase();
let mimeType = 'image/png';
if (ext === '.jpg' || ext === '.jpeg') mimeType = 'image/jpeg';
if (ext === '.gif') mimeType = 'image/gif';
if (ext === '.webp') mimeType = 'image/webp';

const fileName = path.basename(imagePath);

// Prepare request data
const postData = JSON.stringify({
    fileName: fileName,
    base64Data: base64Data,
    mimeType: mimeType
});

const options = {
    hostname: 'localhost',
    port: 3000,
    path: '/upload/logo',
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
    }
};

console.log('🚀 Logo yükleniyor...');
const req = http.request(options, (res) => {
    let data = '';

    res.on('data', (chunk) => {
        data += chunk;
    });

    res.on('end', () => {
        if (res.statusCode === 200) {
            const response = JSON.parse(data);
            console.log('\n✅ Logo başarıyla yüklendi!');
            console.log('📎 URL:', response.url);
            console.log('\nBu URL\'yi kodda kullanabilirsiniz:');
            console.log(response.url);
        } else {
            console.error('❌ Hata:', res.statusCode);
            console.error('Yanıt:', data);
        }
    });
});

req.on('error', (error) => {
    console.error('❌ İstek hatası:', error.message);
    console.error('Backend\'in çalıştığından emin olun: http://localhost:3000');
});

req.write(postData);
req.end();

