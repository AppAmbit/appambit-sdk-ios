# Bug Review #2 — CMS AppAmbitSdk (post-refactor)

Rama: `refactor/removed-cache`  
Archivos revisados: `CmsQuery.swift`, `Cms.swift`, `CmsEndpoint.swift`, `AppAmbitApiService.swift`, `CmsViewController.m`, `CmsExampleModel.h/.m`, `CmsView.swift`

> El refactor de eliminar el cache SQLite local es correcto en concepto. Los filtros, ordenamiento y paginación ahora van como query params al servidor. Los bugs del reporte anterior ya no aplican. Este documento cubre los bugs encontrados en la implementación nueva.

---

## Bugs en Swift (SDK + CmsView)

---

### Bug #1 — ALTO: `getList` devuelve `[]` en error — imposible distinguir falla de lista vacía

**Archivo:** `AppAmbitSdk/Sources/CmsQuery.swift:80-88`

```swift
guard let responseDict = result.data else {
    debugPrint("Cms [fetch error]: \(String(describing: result.errorType))")
    completion([])   // ← timeout, 401, 500, sin red → todo devuelve []
    return
}
guard case let .array(dataArray) = responseDict["data"] else {
    completion([])   // ← respuesta malformada → también []
    return
}
```

Cualquier falla (sin red, 401, 500, respuesta inesperada) llama `completion([])`. `CmsView` recibe `[]`, oculta el spinner y muestra lista vacía. El usuario no puede saber si no hay contenido o si el request falló. No hay forma de mostrar un mensaje de error ni un botón de retry.

**Cómo replicarlo:**
1. Poner el simulador en modo avión.
2. Navegar a la tab CMS.
3. La lista aparece vacía sin ningún indicador de error.

**Solución:**

```swift
// ICmsQuery.swift — extender sin romper compatibilidad
func getList(
    completion: @escaping @Sendable ([T]) -> Void,
    onError: (@Sendable (Error) -> Void)? = nil
)

// CmsQuery.getList
guard let responseDict = result.data else {
    let err = NSError(domain: "CmsQuery", code: result.errorType?.rawValue ?? -1,
                      userInfo: [NSLocalizedDescriptionKey: "Fetch failed: \(String(describing: result.errorType))"])
    onError?(err)
    completion([])
    return
}
```

---

### Bug #2 — ALTO: CMS falla silenciosamente en el primer lanzamiento — `X-App-Key` ausente hasta que completa el registro

**Archivo:** `AppAmbitSdk/Sources/Services/AppAmbitApiService.swift:219-224`

```swift
if endpoint is CmsEndpoint {
    if let appId = try? ServiceContainer.shared.storageService.getAppId() {
        request.addValue(appId, forHTTPHeaderField: "X-App-Key")
    }
    return   // ← siempre sale, aunque appId sea nil
}
```

En el primer lanzamiento, `appId` no está almacenado hasta que `ConsumerService` completa el registro asíncrono. Si el usuario navega a CMS antes, el request sale sin `X-App-Key` → servidor devuelve 401 → `handleTokenRefresh` agrega `Bearer` token (incorrecto para CMS) → sigue fallando → `completion([])` silencioso.

**Cómo replicarlo:**
1. Primer lanzamiento limpio (borrar la app del simulador).
2. Abrir la app y navegar a CMS de inmediato antes de que el SDK termine el registro.
3. La lista aparece vacía y no se reintenta.

**Solución:**

```swift
if endpoint is CmsEndpoint {
    guard let appId = try? ServiceContainer.shared.storageService.getAppId(),
          !appId.isEmpty else {
        completion(.fail(.unauthorized, message: "SDK not yet initialized — X-App-Key unavailable"))
        return
    }
    request.addValue(appId, forHTTPHeaderField: "X-App-Key")
    return
}
```

---

### Bug #3 — MEDIO: Race condition en cambios rápidos de filtro — la UI puede mostrar el resultado equivocado

**Archivo:** `AppAmbitSdk/Sources/CmsQuery.swift:77`, `Samples/AppAmbit.App.Swift/CmsView.swift:90`

Cada tap en "Apply" dispara un nuevo request de red. No hay cancelación del anterior. Si el usuario cambia el filtro dos veces rápido, el primer request puede llegar después del segundo y sobreescribir la UI con el resultado equivocado.

**Cómo replicarlo:**
1. Seleccionar "Views > 1000" → Apply (request A sale).
2. Inmediatamente seleccionar "Sort Title ↑" → Apply (request B sale).
3. Si A llega después de B, la UI muestra "Views > 1000" aunque el usuario pidió "Sort Title ↑".

**Solución en CmsView:**

```swift
@State private var currentRequestId = UUID()

private func loadPosts() {
    isLoading = true
    let myId = UUID()
    currentRequestId = myId
    let query = Cms.content("blog_extended", modelType: CmsExampleModel.self)
    // ... aplicar filtros ...
    query.getList { results in
        DispatchQueue.main.async {
            guard self.currentRequestId == myId else { return }  // descarta respuesta vieja
            self.posts = results
            self.isLoading = false
        }
    }
}
```

---

### Bug #4 — MEDIO: `search` cambia el path del endpoint — combinar con otros filtros puede ser ignorado silenciosamente

**Archivo:** `AppAmbitSdk/Sources/CmsQuery.swift:15`, `AppAmbitSdk/Sources/Services/Endpoints/CmsEndpoint.swift:10`

```swift
// CmsQuery.search
isSearch = true
queryParams.append(("q", trimmed))

// CmsEndpoint
let path = isSearch ? "/\(contentType)/search" : "/\(contentType)"
```

Llamar `.search("swift")` cambia el path a `/blog_extended/search`. Si además se aplica `.equals("is_published", "true")`, el request va a `/blog_extended/search?q=swift&filter[is_published]=true`. Si el endpoint `/search` del servidor no soporta parámetros `filter[...]`, esos filtros son ignorados sin ningún error.

**Solución:** Documentar explícitamente en el protocolo `ICmsQuery` que `search` es mutuamente excluyente con otros filtros, o lanzar un `assertionFailure` en debug si se detecta la combinación.

---

## Bugs específicos de Objective-C

---

### Bug #5 — ALTO (ObjC): Código muerto `isKindOfClass:[NSDictionary class]` en `loadPosts` y `searchPosts` — leftover del API viejo

**Archivo:** `Samples/AppAmbit.App.ObjC/CmsViewController.m:414-420` (y líneas 441-447)

```objc
[query getListWithCompletion:^(NSArray * _Nonnull items) {
    NSArray *actualItems = items;
    if ([items isKindOfClass:[NSDictionary class]]) {   // ← NUNCA puede ser true
        NSDictionary *dict = (NSDictionary *)items;
        if ([dict[@"data"] isKindOfClass:[NSArray class]]) {
            actualItems = dict[@"data"];
        }
    }
    for (NSDictionary *d in actualItems) { ... }
}];
```

`getListWithCompletion:` siempre devuelve un `NSArray` (mapeado desde `[JSONValue]` via `toAny()`). La comprobación `isKindOfClass:[NSDictionary class]` nunca puede ser `YES`. Es código muerto dejado del API anterior donde `getList` podía devolver el dict completo de la respuesta. La variable `actualItems` siempre es igual a `items`.

**Impacto:** Nulo hoy, pero es confuso y podría llevar a malentender el API en el futuro.

**Solución:** Eliminar el bloque de verificación `NSDictionary`:

```objc
[query getListWithCompletion:^(NSArray * _Nonnull items) {
    NSMutableArray *postObjs = [NSMutableArray new];
    for (NSDictionary *d in items) {
        if ([d isKindOfClass:[NSDictionary class]]) {
            [postObjs addObject:[[CmsExampleModel alloc] initWithDictionary:d]];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_posts = postObjs;
        [self->_tableView reloadData];
        [self->_pview stopAnimating];
    });
}];
```

---

### Bug #6 — MEDIO (ObjC): Imagen de celda flickea al hacer scroll — falta cancelar el data task en reuso de celda

**Archivo:** `Samples/AppAmbit.App.ObjC/CmsViewController.m:192-206`

```objc
[[[NSURLSession sharedSession] dataTaskWithURL:url
    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data) {
            UIImage *img = [UIImage imageWithData:data];
            if (img) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.featuredImageView.image = img;  // ← puede actualizar celda reutilizada
                });
            }
        }
    }] resume];
```

Cuando el usuario hace scroll rápido, la celda es reutilizada (`dequeueReusableCellWithIdentifier:`). El data task anterior sigue en vuelo y al completar escribe la imagen del post anterior sobre el post nuevo que ocupa esa celda. El resultado es que las imágenes aparecen mezcladas por un instante (flickering).

**Cómo replicarlo:**
1. Cargar el CMS con varios posts que tengan `featuredImage`.
2. Hacer scroll rápido hacia abajo y de vuelta arriba.
3. Las imágenes de los posts parpadean mostrando brevemente la imagen del post incorrecto.

**Solución:** Guardar el task activo en la celda y cancelarlo antes de iniciar uno nuevo:

```objc
// En PostTableViewCell, agregar una propiedad:
@property (nonatomic, strong, nullable) NSURLSessionDataTask *imageTask;

// En configureWithPost:, antes de iniciar el nuevo task:
[self.imageTask cancel];
self.imageTask = nil;

// Y asignarlo:
self.imageTask = [[NSURLSession sharedSession] dataTaskWithURL:url
    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
            UIImage *img = [UIImage imageWithData:data];
            if (img) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.featuredImageView.image = img;
                });
            }
        }
    }];
[self.imageTask resume];
```

---

### Bug #7 — MEDIO (ObjC): Mismo race condition de Swift — requests concurrentes sobrescriben la UI

**Archivo:** `Samples/AppAmbit.App.ObjC/CmsViewController.m:386` y `433`

Igual que en Swift (Bug #3): `loadPosts` y `searchPosts` no cancelan ni descartan requests anteriores. Si el usuario toca "Apply" dos veces rápido, el resultado del primero puede llegar después del segundo y sobreescribir `_posts` con datos incorrectos.

**Solución:** Usar un token de versión de request, igual que en Swift:

```objc
// En el @interface privado:
NSInteger _requestToken;

// En loadPosts:
- (void)loadPosts {
    [_pview startAnimating];
    NSInteger myToken = ++_requestToken;
    CmsQueryObjC *query = [Cms contentWithType:@"blog_extended"];
    // ... filtros ...
    [query getListWithCompletion:^(NSArray * _Nonnull items) {
        if (myToken != self->_requestToken) { return; }  // descarta respuesta vieja
        // ... procesar y recargar tabla ...
    }];
}
```

---

## Resumen completo

| # | Plataforma | Severidad | Archivo / Línea | Descripción |
|---|------------|-----------|-----------------|-------------|
| 1 | Swift | Alto | `CmsQuery.swift:80-88` | `getList` devuelve `[]` en error — sin distinción entre lista vacía y falla |
| 2 | Swift | Alto | `AppAmbitApiService.swift:219-224` | Sin `X-App-Key` en primer lanzamiento — CMS falla silenciosamente |
| 3 | Swift | Medio | `CmsView.swift:90` | Sin cancelación de request — race condition en cambios rápidos de filtro |
| 4 | Swift | Medio | `CmsQuery.swift:15` | `search` + otros filtros combinados pueden ser ignorados por el servidor |
| 5 | ObjC | Alto | `CmsViewController.m:414` | Código muerto del API anterior — `isKindOfClass:[NSDictionary class]` nunca es true |
| 6 | ObjC | Medio | `CmsViewController.m:192` | Sin cancelación de image task en reuso de celda — flickering de imágenes |
| 7 | ObjC | Medio | `CmsViewController.m:386,433` | Mismo race condition que Swift #3 — requests concurrentes sobrescriben la UI |
