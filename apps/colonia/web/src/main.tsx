import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import '@nucleo/estilos/base.css'
import './estilos.css'
import { ProveedorSesion } from '@nucleo/acceso/Sesion'
import { App } from './App'

createRoot(document.getElementById('raiz')!).render(
  <StrictMode>
    <ProveedorSesion producto="colonia">
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </ProveedorSesion>
  </StrictMode>,
)
