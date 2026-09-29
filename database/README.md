# Connect SocialQuest to Supabase

1. Create a new Supabase project.
2. In its SQL Editor, run `schema.sql` in full.
3. Copy the project URL and **anon** key into a local `.env` file using `.env.example` as a template.
4. Enable Email authentication in Supabase Authentication settings.

Never put a Supabase `service_role` key into the website. It bypasses database security.
