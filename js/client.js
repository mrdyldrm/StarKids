// Supabase istemcisi — tüm sayfalar bu dosyayı kullanır
const { createClient } = supabase;
const supabaseClient = createClient(CONFIG.supabase.url, CONFIG.supabase.anonKey);
