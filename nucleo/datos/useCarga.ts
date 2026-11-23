// Carga asíncrona con estado y error en español. recargar() vuelve a pedir.
import { useCallback, useEffect, useRef, useState } from 'react'

export function useCarga<T>(fn: () => Promise<T>, deps: unknown[]) {
  const [datos, setDatos] = useState<T | null>(null)
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(true)
  const vivo = useRef(true)
  const cargar = useCallback(async () => {
    setCargando(true); setError('')
    try { const d = await fn(); if (vivo.current) setDatos(d) }
    catch (e) { if (vivo.current) setError(e instanceof Error ? e.message : 'Algo falló.') }
    finally { if (vivo.current) setCargando(false) }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)
  useEffect(() => { vivo.current = true; cargar(); return () => { vivo.current = false } }, [cargar])
  return { datos, error, cargando, recargar: cargar, setDatos }
}

// Ejecuta una acción mostrando ocupado y el error si falla.
export function useAccion() {
  const [ocupado, setOcupado] = useState(false)
  const [error, setError] = useState('')
  const correr = async (fn: () => Promise<unknown>) => {
    setOcupado(true); setError('')
    try { await fn(); return true }
    catch (e) { setError(e instanceof Error ? e.message : 'Algo falló.'); return false }
    finally { setOcupado(false) }
  }
  return { ocupado, error, correr, setError }
}
