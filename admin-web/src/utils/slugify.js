export function slugify(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

export function createWordId(no, word) {
  const paddedNo = String(no || '').padStart(3, '0');
  const wordSlug = slugify(word);
  return `${paddedNo}_${wordSlug}`.replace(/^_+|_+$/g, '');
}
