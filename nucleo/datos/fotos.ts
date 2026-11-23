// Fotos tomadas con el teléfono: se achican en el navegador antes de subirlas (una foto de cámara pesa 3–6 MB; así queda en
// unos cientos de KB y sube rápido con datos móviles). Lado mayor ~1600 px, JPEG ~0.8. Si el navegador no puede leer la
// imagen (formato raro), se sube tal cual y el bucket decide si la acepta.
export async function comprimirImagen(archivo: Blob, lado = 1600, calidad = 0.8): Promise<Blob> {
  let fuente: ImageBitmap | HTMLImageElement
  try {
    fuente = await createImageBitmap(archivo, { imageOrientation: 'from-image' })
  } catch {
    try { fuente = await cargarImagen(archivo) } catch { return archivo }
  }
  const ancho = 'naturalWidth' in fuente ? fuente.naturalWidth : fuente.width
  const alto = 'naturalHeight' in fuente ? fuente.naturalHeight : fuente.height
  const escala = Math.min(1, lado / Math.max(ancho, alto, 1))
  const lienzo = document.createElement('canvas')
  lienzo.width = Math.max(1, Math.round(ancho * escala))
  lienzo.height = Math.max(1, Math.round(alto * escala))
  const ctx = lienzo.getContext('2d')
  if (!ctx) return archivo
  ctx.fillStyle = '#fff' // un PNG con transparencia no queda negro en JPEG
  ctx.fillRect(0, 0, lienzo.width, lienzo.height)
  ctx.drawImage(fuente, 0, 0, lienzo.width, lienzo.height)
  if ('close' in fuente) fuente.close()
  const blob = await new Promise<Blob | null>((ok) => lienzo.toBlob(ok, 'image/jpeg', calidad))
  return blob && blob.size < archivo.size ? blob : archivo.type === 'image/jpeg' || !blob ? archivo : blob
}

function cargarImagen(archivo: Blob): Promise<HTMLImageElement> {
  return new Promise((ok, mal) => {
    const url = URL.createObjectURL(archivo)
    const img = new Image()
    img.onload = () => { URL.revokeObjectURL(url); ok(img) }
    img.onerror = () => { URL.revokeObjectURL(url); mal(new Error('imagen_ilegible')) }
    img.src = url
  })
}
