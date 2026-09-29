import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

export const supabase = createClient(
  'https://tbvdrfgnvdarutapvqjl.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRidmRyZmdudmRhcnV0YXB2cWpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA2NjUyNDYsImV4cCI6MjEwNjI0MTI0Nn0.Dp2d-N2xWSXwqAWhiQVmspxpSYJPyX25tq1rj5JaHCw'
);
