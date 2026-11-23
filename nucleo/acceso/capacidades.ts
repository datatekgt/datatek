// Capacidades: copia de public.dt_capacidades_rol (database/nucleo/07_capacidades.sql, la última versión). La base manda; esto es presentación.
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
  ver_agenda: 'Ver la agenda',
  registrar_consulta: 'Registrar consultas',
  registrar_dosis: 'Registrar vacunas y desparasitantes',
  corregir_dosis: 'Corregir una dosis (con motivo)',
  ver_rutas: 'Ver rutas y visitas',
  registrar_servicio: 'Registrar recargas y revisiones',
  emitir_constancia: 'Emitir constancias',
  ver_condominio: 'Ver el condominio',
  registrar_gasto: 'Registrar gastos',
  publicar_gasto: 'Publicar el gasto a los vecinos',
  gestionar_reportes: 'Atender reportes de vecinos',
  ver_obras: 'Ver obras',
  editar_plan: 'Editar el plan de la obra',
  registrar_visita: 'Registrar visitas de supervisión',
  recibir_fase: 'Recibir una fase (libera el pago)',
  publicar_reporte: 'Publicar el reporte al dueño',
  proponer_cambio: 'Proponer cambios',
} as const
export type Capacidad = keyof typeof CAPACIDADES

const NUCLEO_DUENO: Capacidad[] = ['ver_panel', 'ver_clientes', 'crear_acceso', 'ver_calendario', 'mover_calendario', 'ver_dinero', 'cobrar', 'anular_cobro',
  'ver_resultados', 'importar', 'enviar_recordatorios', 'configurar_negocio']
const TALLER_FLOTA: Capacidad[] = ['ver_ordenes', 'cotizar', 'registrar_trabajo', 'verificar_trabajo', 'escanear_unidad']
const CLINICA_HUELLA: Capacidad[] = ['ver_agenda', 'registrar_consulta', 'registrar_dosis', 'corregir_dosis']
const PROPIAS: Record<Producto, Capacidad[]> = {
  flota: TALLER_FLOTA,
  huella: CLINICA_HUELLA,
  fuego: ['ver_rutas', 'registrar_servicio', 'emitir_constancia'],
  colonia: ['ver_condominio', 'registrar_gasto', 'publicar_gasto', 'gestionar_reportes'],
  obra: ['ver_obras', 'editar_plan', 'registrar_visita', 'recibir_fase', 'publicar_reporte', 'proponer_cambio'],
}
const TECNICO: Record<Producto, Capacidad[]> = {
  flota: ['ver_ordenes', 'registrar_trabajo', 'escanear_unidad'],
  huella: ['ver_clientes', 'ver_agenda', 'registrar_consulta', 'registrar_dosis'],
  fuego: ['ver_clientes', 'ver_rutas', 'registrar_servicio'],
  colonia: ['ver_condominio', 'gestionar_reportes'],
  obra: ['ver_clientes', 'ver_obras', 'registrar_visita', 'proponer_cambio'],
}
const CAJA: Record<Producto, Capacidad[]> = { flota: [], huella: ['ver_agenda'], fuego: [], colonia: ['ver_condominio'], obra: ['ver_obras'] }

export function capacidadesRol(producto: Producto, rol: string): Capacidad[] {
  switch (rol) {
    case 'dueno': return [...NUCLEO_DUENO, ...PROPIAS[producto]]
    case 'jefe': return ['ver_panel', 'ver_clientes', 'crear_acceso', 'ver_calendario', 'mover_calendario', 'importar', 'enviar_recordatorios', ...PROPIAS[producto]]
    case 'tecnico': return ['ver_calendario', ...TECNICO[producto]]
    case 'caja': return ['ver_panel', 'ver_clientes', 'ver_calendario', 'ver_dinero', 'cobrar', ...CAJA[producto]]
    default: return []
  }
}

export const ROLES: Record<string, string> = { dueno: 'Dueño', jefe: 'Jefe de taller', tecnico: 'Técnico', caja: 'Caja', sin_rol: 'Sin rol' }
