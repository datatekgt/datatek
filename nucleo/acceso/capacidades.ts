// Capacidades: copia de public.dt_capacidades_rol (database/nucleo/01_acceso.sql). La base manda; esto es presentación.
// scripts/capacidades-iguales.mjs compara las dos y falla si se separan.
export type Producto = 'flota' | 'huella' | 'fuego' | 'colonia' | 'obra'

export const CAPACIDADES = {
  ver_panel: 'Ver el resumen',
  ver_clientes: 'Ver clientes y sus unidades',
  crear_acceso: 'Dar acceso a clientes',
  ver_calendario: 'Ver el calendario',
  mover_calendario: 'Mover el calendario',
  ver_dinero: 'Ver cobros y saldos',
  cobrar: 'Cobrar',
  anular_cobro: 'Anular cobros',
  ver_resultados: 'Ver resultados',
  importar: 'Importar datos',
  enviar_recordatorios: 'Enviar recordatorios',
  configurar_negocio: 'Configurar el negocio y su equipo',
  ver_ordenes: 'Ver y mover órdenes',
  cotizar: 'Cotizar',
  registrar_trabajo: 'Registrar trabajo',
  verificar_trabajo: 'Verificar trabajo',
  escanear_unidad: 'Escanear unidades',
} as const
export type Capacidad = keyof typeof CAPACIDADES

const NUCLEO_DUENO: Capacidad[] = ['ver_panel', 'ver_clientes', 'crear_acceso', 'ver_calendario', 'mover_calendario', 'ver_dinero', 'cobrar', 'anular_cobro',
  'ver_resultados', 'importar', 'enviar_recordatorios', 'configurar_negocio']
const TALLER_FLOTA: Capacidad[] = ['ver_ordenes', 'cotizar', 'registrar_trabajo', 'verificar_trabajo', 'escanear_unidad']

export function capacidadesRol(producto: Producto, rol: string): Capacidad[] {
  const flota = producto === 'flota'
  switch (rol) {
    case 'dueno': return [...NUCLEO_DUENO, ...(flota ? TALLER_FLOTA : [])]
    case 'jefe': return ['ver_panel', 'ver_clientes', 'crear_acceso', 'ver_calendario', 'mover_calendario', 'importar', 'enviar_recordatorios', ...(flota ? TALLER_FLOTA : [])]
    case 'tecnico': return ['ver_calendario', ...(flota ? (['ver_ordenes', 'registrar_trabajo', 'escanear_unidad'] as Capacidad[]) : [])]
    case 'caja': return ['ver_panel', 'ver_clientes', 'ver_calendario', 'ver_dinero', 'cobrar']
    default: return []
  }
}

export const ROLES: Record<string, string> = { dueno: 'Dueño', jefe: 'Jefe de taller', tecnico: 'Técnico', caja: 'Caja', sin_rol: 'Sin rol' }
