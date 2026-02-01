import { createClient } from '@supabase/supabase-js';

// These will be pulled from Vercel Environment Variables
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

export default async function handler(req, res) {
    // Add simple CORS headers for safety
    res.setHeader('Access-Control-Allow-Credentials', true);
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
    res.setHeader(
        'Access-Control-Allow-Headers',
        'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
    );

    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    const { email, source } = req.body;

    if (!email || !email.includes('@')) {
        return res.status(400).json({ error: 'Invalid email address' });
    }

    try {
        // We insert into a table called 'Waitlist'
        // Ensure you have created this table in Supabase Dashboard or via SQL
        const { data, error } = await supabase
            .from('Waitlist')
            .upsert({ email, source: source || 'website' }, { onConflict: 'email' });

        if (error) throw error;

        return res.status(200).json({ success: true });
    } catch (error) {
        console.error('Waitlist error:', error);
        return res.status(500).json({ error: 'Failed to join waitlist' });
    }
}
