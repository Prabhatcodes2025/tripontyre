import { supabase } from '../lib/supabase';
import { ConfigurationError } from './platform';

export const SITE_MEDIA_BUCKET = 'site-media';
export const MAX_MEDIA_FILE_SIZE = 8 * 1024 * 1024;

const ALLOWED_MEDIA_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const EXTENSIONS: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

export type SiteMediaUpload = {
  path: string;
  publicUrl: string;
  mimeType: string;
  size: number;
};

export type SiteMediaUploadOptions = {
  folder: string;
  onProgress?: (progress: number) => void;
  upsert?: boolean;
};

function requireClient() {
  if (!supabase) throw new ConfigurationError('Supabase Storage is not configured.');
  return supabase;
}

function safeSegment(value: string) {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
}

export function validateMediaFile(file: File) {
  if (!ALLOWED_MEDIA_TYPES.has(file.type)) {
    throw new Error('Choose a JPG, PNG or WebP image.');
  }
  if (file.size <= 0) throw new Error('The selected image is empty.');
  if (file.size > MAX_MEDIA_FILE_SIZE) {
    throw new Error('Images must be 8 MB or smaller.');
  }
}

export function getSiteMediaPublicUrl(path: string) {
  const cleanPath = path.replace(/^\/+/, '');
  if (!cleanPath) throw new Error('A Storage path is required.');
  return requireClient().storage.from(SITE_MEDIA_BUCKET).getPublicUrl(cleanPath).data.publicUrl;
}

export function siteMediaPathFromUrl(value: string) {
  const marker = `/storage/v1/object/public/${SITE_MEDIA_BUCKET}/`;
  const index = value.indexOf(marker);
  if (index < 0) return null;
  const encodedPath = value.slice(index + marker.length).split(/[?#]/, 1)[0];
  try {
    return encodedPath.split('/').map(decodeURIComponent).join('/');
  } catch {
    return null;
  }
}

export async function uploadSiteMedia(file: File, options: SiteMediaUploadOptions): Promise<SiteMediaUpload> {
  validateMediaFile(file);
  const api = requireClient();
  const folder = safeSegment(options.folder);
  if (!folder) throw new Error('A valid media folder is required.');

  const { data: sessionData, error: sessionError } = await api.auth.getSession();
  if (sessionError) throw sessionError;
  const accessToken = sessionData.session?.access_token;
  if (!accessToken) throw new Error('Your session has expired. Sign in and retry the upload.');

  const originalName = safeSegment(file.name.replace(/\.[^.]+$/, '')) || 'image';
  const path = `${folder}/${new Date().toISOString().slice(0, 10)}/${crypto.randomUUID()}-${originalName}.${EXTENSIONS[file.type]}`;
  const encodedPath = path.split('/').map(encodeURIComponent).join('/');
  const projectUrl = String(import.meta.env.VITE_SUPABASE_URL || '').replace(/\/$/, '');
  const anonKey = String(import.meta.env.VITE_SUPABASE_ANON_KEY || '');
  if (!projectUrl || !anonKey) throw new ConfigurationError('Supabase Storage is not configured.');

  await new Promise<void>((resolve, reject) => {
    const request = new XMLHttpRequest();
    request.open('POST', `${projectUrl}/storage/v1/object/${SITE_MEDIA_BUCKET}/${encodedPath}`);
    request.setRequestHeader('Authorization', `Bearer ${accessToken}`);
    request.setRequestHeader('apikey', anonKey);
    request.setRequestHeader('Content-Type', file.type);
    request.setRequestHeader('x-upsert', options.upsert ? 'true' : 'false');
    request.upload.addEventListener('progress', event => {
      if (event.lengthComputable) options.onProgress?.(Math.round((event.loaded / event.total) * 100));
    });
    request.addEventListener('load', () => {
      if (request.status >= 200 && request.status < 300) {
        options.onProgress?.(100);
        resolve();
        return;
      }
      let message = `Upload failed (${request.status}).`;
      try {
        const payload = JSON.parse(request.responseText) as { message?: string; error?: string };
        message = payload.message || payload.error || message;
      } catch {
        // The status-based message is safe when Storage did not return JSON.
      }
      reject(new Error(message));
    });
    request.addEventListener('error', () => reject(new Error('The upload was interrupted. Check your connection and retry.')));
    request.addEventListener('abort', () => reject(new Error('The upload was cancelled.')));
    request.send(file);
  });

  return { path, publicUrl: getSiteMediaPublicUrl(path), mimeType: file.type, size: file.size };
}

export async function removeSiteMedia(pathOrUrl: string) {
  const path = siteMediaPathFromUrl(pathOrUrl) || pathOrUrl.replace(/^\/+/, '');
  if (!path || path.includes('..')) throw new Error('The Storage path is invalid.');
  const { error } = await requireClient().storage.from(SITE_MEDIA_BUCKET).remove([path]);
  if (error) throw error;
}
