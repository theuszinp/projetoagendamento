const { createClient } = require('@supabase/supabase-js');

const supabaseUrl =
    process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseKey =
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.SUPABASE_ANON_KEY ||
    process.env.SUPABASE_PUBLISHABLE_DEFAULT_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY ||
    '';
const bucketName = process.env.SUPABASE_STORAGE_BUCKET || 'ticket-attachments';

let supabaseClient = null;

function getSupabaseClient() {
    if (!supabaseUrl || !supabaseKey) {
        throw new Error('Configuração do Supabase Storage ausente no .env.');
    }

    if (!supabaseClient) {
        supabaseClient = createClient(supabaseUrl, supabaseKey, {
            auth: {
                autoRefreshToken: false,
                persistSession: false,
            },
        });
    }

    return supabaseClient;
}

function sanitizeFileName(fileName) {
    return fileName
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9.\-_]+/g, '-')
        .replace(/-+/g, '-')
        .replace(/^-|-$/g, '');
}

async function uploadTicketAttachment({
    ticketId,
    fileName,
    contentType,
    base64Content,
}) {
    const client = getSupabaseClient();
    const safeName = sanitizeFileName(fileName || 'foto-instalacao.jpg') || 'foto-instalacao.jpg';
    const extension = safeName.includes('.') ? '' : '.jpg';
    const storagePath = `tickets/${ticketId}/${Date.now()}-${safeName}${extension}`;
    const fileBuffer = Buffer.from(base64Content, 'base64');

    const { error: uploadError } = await client.storage
        .from(bucketName)
        .upload(storagePath, fileBuffer, {
            contentType: contentType || 'image/jpeg',
            upsert: false,
        });

    if (uploadError) {
        throw uploadError;
    }

    const { data } = client.storage.from(bucketName).getPublicUrl(storagePath);

    return {
        bucketName,
        storagePath,
        publicUrl: data.publicUrl,
    };
}

module.exports = {
    bucketName,
    uploadTicketAttachment,
};
