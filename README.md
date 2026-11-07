# 👁️ Ocularis-XR

Nowoczesna symulacja XR wad wzroku stworzona na gogle **Meta Quest 3**.  
Użytkownik w trybie **Mixed Reality / Passthrough (Meta XR SDK)** ma okazję doświadczyć, jak wygląda prawdziwy świat oraz otaczające go przedmioty oczami osoby cierpiącej na wybrane schorzenia okulistyczne i wady refrakcji.

> **Współpraca naukowa:**  
> Projekt powstaje we współpracy z **Panią Doktor Magdaleną Grajek** z Wydziału Fizyki i Astronomii Uniwersytetu im. Adama Mickiewicza w Poznaniu (**WFiA UAM**).

---

## 🛠️ Stos technologiczny

- **Silnik:** Unity `6.5` (`6000.5.5f1`)
- **Potok renderowania:** Universal Render Pipeline (URP `17.5.0`) + Single Pass Instanced Stereo
- **Platforma docelowa:** Meta Quest 3
- **SDK XR:** Meta XR SDK (`207.0.1`), Meta MR Utility Kit (MRUK), Meta Environment Depth API (`Occlusion`)

---

## 🏗️ Architektura systemu wad wzroku

System został zaprojektowany w oparciu o **modularną architekturę obiektów typu On/Off**, łączącą sprzętowe możliwości kompozytora Passthrough na Meta Quest 3, mapę głębi otoczenia (Depth API), post-processing URP oraz lekkie, jednozadaniowe shadery HLSL.

### Hierarchia obiektów w scenie (`MainScene`)

```text
[BuildingBlock] Camera Rig (VisionDefectManager)
 └── TrackingSpace
      └── CenterEyeAnchor (Camera)
           └── VisionDefects (kontener wad wzroku)
                ├── Defect_Zacma                  [GameObject On/Off]
                ├── Defect_Jaskra                 [GameObject On/Off]
                ├── Defect_AMD                    [GameObject On/Off]
                ├── Defect_Mety                   [GameObject On/Off]
                ├── Defect_Krotkowzrocznosc       [GameObject On/Off]
                └── Defect_Nadwzrocznosc          [GameObject On/Off]
```

### Główne założenia techniczne

1. **Osobny `GameObject` na każdą wadę (Wzorzec On/Off):**
   - Każda wada wzroku jest niezależnym obiektem w hierarchii podpiętym pod `CenterEyeAnchor`.
   - Włączenie wady aktywuje jej `GameObject` (`SetActive(true)`), natomiast wyłączenie dezaktywuje go (`SetActive(false)`) i automatycznie przywraca domyślne ustawienia współdzielonych komponentów (`OVRPassthroughLayer`, `Global Volume`).
2. **Korekcja stereoskopowa per-oko (Brak efektu zeza na nakładkach):**
   - Zamiast płaskiego `Canvas` UI, każda wada korzysta z lekkiego mesha `OverlayQuad` umieszczonego przed kamerą (`z = 0.12m`).
   - Dedykowane shadery URP obliczają współrzędne kątowe bezpośrednio w przestrzeni widoku aktualnie renderowanego oka (`TransformWorldToView` + `UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX`), dzięki czemu środek wady (np. tunel w jaskrze lub mroczek centralny w AMD) pokrywa się idealnie z osią optyczną **lewego i prawego oka niezależnie**.
3. **Trzy współpracujące warstwy efektów (kompatybilne z kanałem Alpha Passthrough):**
   - **`OVRPassthroughLayer` (Sprzętowy Passthrough):** regulacja kontrastu, jasności, nasycenia barw, obrysów krawędzi i tablic kolorów LUT bezpośrednio na strumieniu z kamer gogli.
   - **Meta Environment Depth API (`_EnvironmentDepthTexture`):** odczyt rzeczywistej odległości w metrach do obiektów w pokoju oraz dłoni użytkownika (wykorzystywany w krótkowzroczności i nadwzroczności).
   - **Dedykowane mikro-shadery URP (`Assets/Scripts/Shaders/`):** osobny, mały shader HLSL dla każdej wady z mieszaniem `Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha`.
   - **Ważna uwaga techniczna (URP + Passthrough):** Na kamerach w `OVRCameraRig` opcja `Render Post Processing` oraz `Opaque/Depth Texture` w `Mobile_RPAsset` pozostają **wyłączone** (`0`), ponieważ pełnoekranowy przebieg post-processingu URP nadpisuje kanał przezroczystości (`alpha = 1.0`), co w trybie *Underlay Passthrough* zasłaniałoby obraz z kamer gogli czarnym tłem.

---

### Kluczowe skrypty (`Assets/Scripts/`)

| Skrypt | Rola w systemie |
| :--- | :--- |
| [`IVisionDefect.cs`](Assets/Scripts/IVisionDefect.cs) | Interfejs pojedynczej wady wzroku (`DefectType`, `IsActive`, `EnableDefect()`, `DisableDefect()`, `SetIntensity(float)`). |
| [`VisionDefectBase.cs`](Assets/Scripts/VisionDefectBase.cs) | Abstrakcyjna klasa bazowa obsługująca cykl życia obiektu On/Off, automatyczne tworzenie `OverlayQuad`, instancjonowanie materiału oraz resetowanie `OVRPassthroughLayer` i `Volume`. |
| [`VisionDefectManager.cs`](Assets/Scripts/VisionDefectManager.cs) | Menedżer główny (na `[BuildingBlock] Camera Rig`). Automatycznie wykrywa wszystkie wady w hierarchii dzieci i udostępnia API dla UI oraz podgląd na żywo w Inspectorze. |

#### Przykład użycia z poziomu kodu / UI

```csharp
// Włączenie wybranej wady z zadaną intensywnością (0.0 - 1.0):
visionDefectManager.ActivateDefect("Zacma", 0.75f);

// Przełącznik typu On/Off (np. pod przycisk w menu XR):
visionDefectManager.ToggleDefect("Jaskra", 1.0f);

// Płynna zmiana natężenia aktualnie włączonej wady (np. pod suwak UI Slider):
visionDefectManager.UpdateCurrentDefectIntensity(sliderValue);

// Wyłączenie wszystkich wad:
visionDefectManager.DeactivateAll();
```

---

## 📋 Status implementacji wad wzroku

### ✅ Zaimplementowane wady wzroku (6 / 13)

| Wada wzroku | Identyfikator (`DefectType`) | Skrypt i Shader | Opis medyczny i sposób symulacji w XR |
| :--- | :--- | :--- | :--- |
| **Zaćma** | `"Zacma"` | [`CataractDefect.cs`](Assets/Scripts/Defects/CataractDefect.cs)<br>[`VisionDefect_Cataract.shader`](Assets/Scripts/Shaders/VisionDefect_Cataract.shader) | Widzenie jak przez zabrudzoną szybę lub mleczno-żółtą mgłę. Obniżony kontrast i wyblakłe kolory na `OVRPassthroughLayer`, proceduralny szum FBM zmętnienia soczewki oraz olśnienie wokół źródeł światła (`Bloom`). |
| **Jaskra** | `"Jaskra"` | [`GlaucomaDefect.cs`](Assets/Scripts/Defects/GlaucomaDefect.cs)<br>[`VisionDefect_Glaucoma.shader`](Assets/Scripts/Shaders/VisionDefect_Glaucoma.shader) | Stopniowy zanik obwodowego pola widzenia aż do tzw. widzenia lunetowego (niewielki okrągły punkt w centrum). Miękki, organicznie nieregularny brzeg wycentrowany niezależnie dla każdego oka. |
| **Zwyrodnienie plamki żółtej (AMD)** | `"AMD"` | [`MacularDegenerationDefect.cs`](Assets/Scripts/Defects/MacularDegenerationDefect.cs)<br>[`VisionDefect_AMD.shader`](Assets/Scripts/Shaders/VisionDefect_AMD.shader) | Ciemna, rozmyta plama w centrum obrazu (mroczek centralny) przysłaniająca punkt fiksacji wzroku. W postaci wysiękowej dodatkowo falowanie prostych linii i deformacja obrazu wokół plamki. |
| **Męty ciała szklistego** | `"Mety"` | [`FloatersDefect.cs`](Assets/Scripts/Defects/FloatersDefect.cs)<br>[`VisionDefect_Floaters.shader`](Assets/Scripts/Shaders/VisionDefect_Floaters.shader) | Półprzezroczyste kropki, nitki i wstążki kolagenowe przesuwające się z bezwładnością (`SmoothDamp`) przy ruchach głowy oraz powoli opadające pod wpływem grawitacji na dwóch warstwach paralaksy. |
| **Krótkowzroczność** | `"Krotkowzrocznosc"` | [`RefractiveErrorDefect.cs`](Assets/Scripts/Defects/RefractiveErrorDefect.cs) (`Myopia`)<br>[`VisionDefect_DepthBlur.shader`](Assets/Scripts/Shaders/VisionDefect_DepthBlur.shader) | Ostre widzenie z bliska (np. własne dłonie, przybliżony kubek `< 0.6m`), natomiast dalszy plan pokoju jest rozmyty. Wykorzystuje rzeczywistą odległość z **Meta Depth API** (`_EnvironmentDepthTexture`) + bufor głębi Unity oraz `DepthOfField`. |
| **Nadwzroczność** | `"Nadwzrocznosc"` | [`RefractiveErrorDefect.cs`](Assets/Scripts/Defects/RefractiveErrorDefect.cs) (`Hyperopia`)<br>[`VisionDefect_DepthBlur.shader`](Assets/Scripts/Shaders/VisionDefect_DepthBlur.shader) | Ostre widzenie w oddali, natomiast trudności z czytaniem i rozmyty obraz przy patrzeniu na obiekty znajdujące się blisko oczu (wykorzystuje Meta Depth API + `DepthOfField`). |

---

### ⏳ Planowane / W kolejce do implementacji (7 / 13)

Poniższe wady zostaną wdrożone w kolejnym kroku jako osobne obiekty dziedziczące po [`VisionDefectBase`](Assets/Scripts/VisionDefectBase.cs):

- **Retinopatia cukrzycowa (`"Retinopatia"`)** – zamazanie i deformacja obrazu centralnego oraz liczne, nieregularne czarne plamy/kropki (wylewy podsiatkówkowe) zaciemniające pole widzenia.
- **Metamorfopsje (`"Metamorfopsje"`)** – globalne lub lokalne zniekształcenie geometrii obrazu: linie proste widziane jako faliste, kratki jako wygięte, a elementy twarzy jako przesunięte.
- **Stożek rogówki (`"StozekRogowki"`)** – rozciągnięte lub wielokrotne kontury (poliopia jednooczna), cienie/duchy obok liter, kierunkowe smugi i stożkowe zniekształcenia.
- **Astygmatyzm (`"Astygmatyzm"`)** – nieostre, kierunkowo rozciągnięte lub podwojone kontury pod wybranym kątem osi cylindra oraz wydłużone smugi świateł.
- **Odwarstwienie siatkówki (`"OdwarstwienieSiatkowki"`)** – nagłe błyski świetlne na obwodzie (fotopsje jak od lampy błyskowej), chmara błyszczących "muszek", a w dalszym stadium ciemna "kurtyna" zasłaniająca pole widzenia z boku.
- **Zaburzenia widzenia barw – Daltonizm (`"Daltonizm"`)** – trudności z odróżnieniem kolorów (Protanopia, Deuteranopia, Tritanopia, Achromatopsja) realizowane sprzętowo poprzez tablice `OVRPassthroughColorLut` oraz korekcję barw URP.
- **Diplopia – Zez (`"Diplopia"`)** – podwójne widzenie jednego przedmiotu z rozdzieleniem obrazów w płaszczyźnie poziomej lub pionowej.

---

## ➕ Jak dodać nową wadę wzroku?

1. Utwórz klasę w `Assets/Scripts/Defects/` dziedziczącą po [`VisionDefectBase`](Assets/Scripts/VisionDefectBase.cs) i zaimplementuj metodę `ApplyDefect(float currentIntensity)`.
2. Jeśli wada wymaga własnego efektu wizualnego na nakładce, utwórz dedykowany shader w `Assets/Scripts/Shaders/` i wskaż jego nazwę we właściwości `DefaultShaderName`.
3. Dodaj nowy pusty `GameObject` jako dziecko `CenterEyeAnchor/VisionDefects` w scenie `MainScene` i podepnij do niego swój skrypt – [`VisionDefectManager`](Assets/Scripts/VisionDefectManager.cs) automatycznie zarejestruje wadę przy starcie aplikacji.
