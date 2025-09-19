# E-vidence

E-vidence es un juego de investigación a traves de un smartphone. Todo ocurre en distintas apps: Mensajería, Galería, Mail, Navegador de internet... Tu trabajo es pillar contradicciones hablando con contactos y mostrarles pruebas (fotos, capturas, emails) para hacer avanzar la historia.

## Documentación de Estructura de Casos JSON

Los casos se definen mediante archivos JSON ubicados en `project/data/` con el formato `case_*.json`. A continuación se documenta la estructura completa y todas las opciones posibles:

### Estructura Principal

```json
{
  "contacts": [...],      // Array de contactos
  "chats": {...},         // Conversaciones por contacto
  "replies": {...},       // Sistema legacy de respuestas simples
  "evidence": [...],      // Catálogo de pruebas/evidencias
  "gallery": [...],       // Items de la galería
  "facts": {...}          // Estados del juego (se inicializa automáticamente)
}
```

### 1. Contacts (Contactos)

Define los contactos disponibles en el caso:

```json
"contacts": [
  {
    "id": "contacto_id",                    // ID único del contacto (requerido)
    "name": "Nombre a mostrar",             // Nombre visible (requerido)
    "avatar": "res://path/to/avatar.jpg",   // Ruta del avatar (opcional)
    "requires": ["fact1", "!fact2"],        // Condiciones para mostrar (opcional)
    "timing": {                             // Configuración de tiempos (opcional)
      "npc_reaction_delay": 0.5,            // Pausa antes de responder (segundos)
      "npc_typing_min": 0.2,                // Tiempo mínimo escribiendo (segundos)
      "npc_typing_max": 0.6,                // Tiempo máximo escribiendo (segundos)
      "npc_between_msgs": 0.3,              // Pausa entre mensajes (segundos)
      "typing_per_char": 0.015              // Tiempo por carácter al escribir (segundos)
    }
  }
]
```

**Campos de `contacts`:**
- `id` (string, requerido): Identificador único del contacto
- `name` (string, requerido): Nombre que se muestra en la interfaz
- `avatar` (string, opcional): Ruta a la imagen del avatar
- `requires` (array, opcional): Condiciones que deben cumplirse para mostrar el contacto
  - Formato: `["fact_name"]` (debe ser true) o `["!fact_name"]` (debe ser false)
- `timing` (object, opcional): Configuración de tiempos de respuesta del NPC

### 2. Chats (Conversaciones)

Define las conversaciones con cada contacto:

```json
"chats": {
  "contacto_id": {
    "history": [                            // Historial de mensajes
      {
        "from": "Nombre",                   // Emisor del mensaje
        "text": "Contenido del mensaje",    // Texto del mensaje
        "image": "res://path/image.jpg"     // Imagen del mensaje (opcional)
      }
    ],
    "options": [                            // Opciones de respuesta del jugador
      {
        "id": "opcion_id",                  // ID único de la opción
        "text": "Texto de la opción",       // Texto que ve el jugador
        "requires": ["fact1", "!fact2"],    // Condiciones para mostrar (opcional)
        "repeatable": true,                 // Si es repetible infinitamente (opcional)
        "max_uses": 2,                      // Máximo número de usos (opcional)
        "effects": [                        // Efectos al usar la opción (opcional)
          "fact_name",                      // Activa un fact
          "give_evidence:evidence_id",      // Da una evidencia
          "unlock_gallery:gallery_id",      // Desbloquea item galería
          "unlock_contact:contact_id"       // Desbloquea contacto
        ],
        "npc_reply": [                      // Respuesta del NPC (opcional)
          "Texto simple",                   // Mensaje de texto
          {                                 // Mensaje con configuración avanzada
            "text": "Mensaje",
            "image": "res://path/img.jpg",  // Imagen del mensaje (opcional)
            "typing_min": 0.2,              // Override tiempo mínimo (opcional)
            "typing_max": 0.6,              // Override tiempo máximo (opcional)
            "between": 0.4,                 // Pausa después del mensaje (opcional)
            "after_delay": 0.4,             // Alias de "between" (opcional)
            "reaction_delay": 1.0           // Pausa antes del mensaje (opcional)
          }
        ]
      }
    ],
    "used_evidence": ["ev1", "ev2"]         // Evidencias ya usadas (interno)
  }
}
```

**Campos de `chats[contact_id]`:**
- `history` (array, opcional): Historial de mensajes de la conversación
  - `from` (string): Nombre del emisor
  - `text` (string): Contenido del mensaje
  - `image` (string, opcional): Ruta a imagen del mensaje
- `options` (array, opcional): Opciones de respuesta disponibles
- `used_evidence` (array, interno): Lista de evidencias ya presentadas a este contacto

**Campos de `options`:**
- `id` (string, requerido): Identificador único de la opción
- `text` (string, requerido): Texto que se muestra al jugador
- `requires` (array, opcional): Condiciones para mostrar la opción
- `repeatable` (boolean, opcional): Si es repetible infinitamente (default: false)
- `max_uses` (number, opcional): Número máximo de usos (default: 1 si no es repetible)
- `effects` (array, opcional): Efectos que se activan al usar la opción
- `npc_reply` (array, opcional): Respuesta del NPC
- `used` (boolean, interno): Si ya se ha usado (controlado automáticamente)
- `uses` (number, interno): Número de veces usada (controlado automáticamente)

**Efectos disponibles en `effects`:**
- `"fact_name"`: Activa un fact booleano
- `"give_evidence:evidence_id"`: Otorga una evidencia al inventario
- `"unlock_gallery:gallery_id"`: Desbloquea un item de galería
- `"unlock_contact:contact_id"`: Desbloquea un contacto

### 3. Replies (Sistema Legacy)

Sistema simple de respuestas (compatible con versiones anteriores):

```json
"replies": {
  "contacto_id": [
    "Primera opción de respuesta",
    "Segunda opción de respuesta"
  ]
}
```

**Nota:** Este sistema es más limitado que `options` y se mantiene por compatibilidad.

### 4. Evidence (Evidencias/Pruebas)

Define las evidencias que el jugador puede obtener y presentar:

```json
"evidence": [
  {
    "id": "evidence_id",                    // ID único de la evidencia
    "name": "Nombre de la evidencia",       // Nombre visible
    "reactions": {                          // Reacciones por contacto
      "contacto_id": {
        "text": "Texto al presentar",       // Texto del jugador (opcional)
        "requires": ["fact1"],              // Condiciones para usar (opcional)
        "effects": ["unlock_gallery:id"],   // Efectos al presentar (opcional)
        "npc_reply": [                      // Respuesta del NPC
          "Respuesta del contacto",
          {
            "text": "Mensaje avanzado",
            "image": "res://path/img.jpg"
          }
        ]
      }
    }
  }
]
```

**Campos de `evidence`:**
- `id` (string, requerido): Identificador único de la evidencia
- `name` (string, requerido): Nombre que se muestra en el inventario
- `reactions` (object, opcional): Reacciones específicas por contacto

**Campos de `reactions[contact_id]`:**
- `text` (string, opcional): Texto que dice el jugador al presentar (default: "Presento una prueba.")
- `requires` (array, opcional): Condiciones para poder presentar la evidencia
- `effects` (array, opcional): Efectos que se activan al presentar
- `npc_reply` (array, opcional): Respuesta del contacto

### 5. Gallery (Galería)

Define los items disponibles en la galería:

```json
"gallery": [
  "res://path/to/image.jpg",               // Imagen siempre visible
  {
    "id": "gallery_id",                    // ID único del item
    "path": "res://path/to/image.jpg",     // Ruta de la imagen
    "requires": ["unlocked_gallery_id"]    // Condiciones para mostrar
  }
]
```

**Formatos de `gallery`:**
- **String simple**: Imagen siempre visible
- **Object**: Item con condiciones
  - `id` (string, requerido): Identificador único
  - `path` (string, requerido): Ruta a la imagen
  - `requires` (array, opcional): Condiciones para mostrar

### 6. Facts (Estado del Juego)

Los facts son variables booleanas que controlan el estado del juego:

```json
"facts": {
  "fact_name": true,
  "another_fact": false
}
```

**Nota:** Este objeto se inicializa automáticamente y se manipula mediante efectos.

### Condiciones (requires)

Las condiciones se evalúan como facts booleanos:

- `"fact_name"`: El fact debe ser `true`
- `"!fact_name"`: El fact debe ser `false` (negación)

### Ejemplos Completos

#### Ejemplo Básico

```json
{
  "contacts": [
    {
      "id": "amigo",
      "name": "Mi Amigo",
      "avatar": "res://avatars/amigo.jpg"
    }
  ],
  "chats": {
    "amigo": {
      "history": [
        {"from": "Mi Amigo", "text": "¡Hola! ¿Cómo estás?"}
      ],
      "options": [
        {
          "id": "bien",
          "text": "¡Muy bien, gracias!",
          "npc_reply": ["Me alegro mucho."]
        }
      ]
    }
  }
}
```

#### Ejemplo Avanzado

```json
{
  "contacts": [
    {
      "id": "detective",
      "name": "Detective López",
      "avatar": "res://avatars/detective.jpg",
      "requires": ["case_started"],
      "timing": {
        "npc_reaction_delay": 1.0,
        "npc_typing_min": 0.3,
        "npc_typing_max": 1.0
      }
    }
  ],
  "chats": {
    "detective": {
      "options": [
        {
          "id": "start_case",
          "text": "Quiero reportar un caso",
          "requires": ["!case_started"],
          "effects": ["case_started", "give_evidence:badge"],
          "npc_reply": [
            "Perfecto, empecemos.",
            {
              "text": "Te doy mi placa como prueba.",
              "image": "res://evidence/badge.jpg",
              "between": 1.0
            }
          ]
        },
        {
          "id": "status",
          "text": "¿Cómo va el caso?",
          "requires": ["case_started"],
          "repeatable": true,
          "npc_reply": ["Avanzamos bien."]
        }
      ]
    }
  },
  "evidence": [
    {
      "id": "badge",
      "name": "Placa del Detective",
      "reactions": {
        "detective": {
          "text": "Te muestro tu propia placa",
          "npc_reply": ["¡Ja! Muy gracioso."]
        }
      }
    }
  ]
}
```

Esta documentación cubre todas las opciones disponibles en la estructura JSON de casos para E-vidence.
