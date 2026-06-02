declare module 'std/server' {
  export function serve(handler: (req: Request) => Response | Promise<Response>): void;
}

declare module '@supabase/supabase-js' {
  export function createClient(url: string, key: string): any;
}

declare module 'nodemailer' {
  const nodemailer: any;
  export default nodemailer;
}

declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

export {};
