# capacitor-ui-kit

plugin that opens the gate to using iOS UIKit in the Capacitor ecosystem

## Install

```bash
npm install @falconeta/capacitor-ui-kit
npx cap sync
```

## Adaptive tab navigation on iOS

The native controller uses UIKit containment and Auto Layout so it receives scene,
window-size and device-trait changes. The default `options.placement: 'automatic'`
lets UIKit choose the bottom bar or vertical rail, including on iPhone Duo when
built with the iOS 27.1 SDK. Set `placement: 'sidebar'` to opt into UIKit's richer
sidebar where the current size class supports it. No device-name check is needed.

Register `onTabBarLayoutChange` before creating tabs. The event reports the physical
placement and **additional** content insets beyond the system safe area, in UIKit
points (CSS pixels with viewport scale 1). Add these values to the corresponding
CSS `env(safe-area-inset-*)`; do not replace the system safe area. A Duo rail may
already be covered by that safe area, in which case its additional inset is zero.
The event updates after resizing, changing placement, hiding or removing tabs.

```ts
const listener = await CapacitorUIKit.addListener('onTabBarLayoutChange', layout => {
  for (const [edge, value] of Object.entries(layout.insets)) {
    document.documentElement.style.setProperty(`--native-tab-${edge}`, `${value}px`);
  }
});
await CapacitorUIKit.initialize();
// Pass placement: 'automatic' (default) in createTabBar's options.
// Remove the listener and your CSS variables when the host view is destroyed.
```

```css
.tab-content {
  right: calc(env(safe-area-inset-right, 0px) + var(--native-tab-right, 0px));
  padding-bottom: calc(env(safe-area-inset-bottom, 0px) + var(--native-tab-bottom, 0px));
}
```

Apply each inset once in the host layout. `showTabBar` / `hideTabBar` control the
adaptive navigation rather than only the legacy horizontal `UITabBar` view.
`tabBarSelected()` returns the item's numeric tag, including after sidebar ordering.
Custom SVG icons are templates and use the configured selected/unselected tints;
`imageSelected` falls back to `image` when omitted or unavailable. The loader
retries SVGKit’s specific PPI-initialization failure on newer device identifiers,
so pixel-sized icons are available on the first creation too.

## Page toolbars

Use `options.adaptive: true` with `createTopToolbar` / `setTopToolbarItems` to place
page actions in the selected tab's `UINavigationController`. UIKit then integrates
back and action items with iPhone Duo's shared vertical region, while keeping the
normal top navigation bar on other layouts. Items before the first flexible spacer
become leading navigation items (for example Back); the remaining items become
trailing actions. The plugin keeps a navigation container available even without
application tabs, so pushed pages can retain their native controls.

`onTopToolbarLayoutChange` reports `placement` (`hidden`, `top`, `left`, `right`) and
`verticalEdge` (`none`, `left`, `right`). The latter also updates while bars are
hidden. Register before showing actions and use the event to release any horizontal
space reserved by web header controls when the native bar is vertical.

Without `adaptive`, `options.position: { top, left, right }` positions a standalone
horizontal toolbar relative to the WebView, in UIKit points (CSS pixels at viewport
scale 1). This remains useful for centered HTML modal headers. Standalone toolbars
do not participate in UIKit's shared vertical region. Omit `position` to use the
controller's safe content layout guide.

Button and menu items accept `data.enabled` (default `true`). Titles are used as
accessibility labels, and as visible text when there is no icon. Toolbar/navigation
background space passes touches through to WebKit; native controls receive taps.
The host must associate actions with the active page, hide covered controls, and
ignore events from pages that have left. Keep web controls available until the
native actions for that same page have actually been shown.

## API

<docgen-index>

* [`presentToast(...)`](#presenttoast)
* [`dismissToast(...)`](#dismisstoast)
* [`dismissWebSheet(...)`](#dismisswebsheet)
* [`completeWebSheetAction(...)`](#completewebsheetaction)
* [`presentActionSheet(...)`](#presentactionsheet)
* [`presentDialog(...)`](#presentdialog)
* [`dismissDialog(...)`](#dismissdialog)
* [`presentWebSheet(...)`](#presentwebsheet)
* [`addListener('onTopToolbarLayoutChange', ...)`](#addlistenerontoptoolbarlayoutchange-)
* [`addListener('onTabBarLayoutChange', ...)`](#addlistenerontabbarlayoutchange-)
* [`addListener(string, ...)`](#addlistenerstring-)
* [`beginTopToolbarTransition(...)`](#begintoptoolbartransition)
* [`updateTopToolbarTransition(...)`](#updatetoptoolbartransition)
* [`finishTopToolbarTransition(...)`](#finishtoptoolbartransition)
* [`initialize()`](#initialize)
* [`reRender()`](#rerender)
* [`createTabBar(...)`](#createtabbar)
* [`removeTabs()`](#removetabs)
* [`createToolbar(...)`](#createtoolbar)
* [`createTopToolbar(...)`](#createtoptoolbar)
* [`setToolbarItems(...)`](#settoolbaritems)
* [`setTopToolbarItems(...)`](#settoptoolbaritems)
* [`showTabBar()`](#showtabbar)
* [`hideTabBar()`](#hidetabbar)
* [`showSearch()`](#showsearch)
* [`hideSearch()`](#hidesearch)
* [`showToolbar()`](#showtoolbar)
* [`hideToolbar()`](#hidetoolbar)
* [`showTopToolbar()`](#showtoptoolbar)
* [`hideTopToolbar()`](#hidetoptoolbar)
* [`tabBarSelected()`](#tabbarselected)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)
* [Enums](#enums)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### presentToast(...)

```typescript
presentToast(options: NativeToastOptions) => Promise<void>
```

Show a non-blocking banner above presented UIKit controllers in the app scene.

| Param         | Type                                                              |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code><a href="#nativetoastoptions">NativeToastOptions</a></code> |

--------------------


### dismissToast(...)

```typescript
dismissToast(options: { id: string; role?: string; }) => Promise<void>
```

| Param         | Type                                        |
| ------------- | ------------------------------------------- |
| **`options`** | <code>{ id: string; role?: string; }</code> |

--------------------


### dismissWebSheet(...)

```typescript
dismissWebSheet(options: { sessionId: string; force?: boolean; }) => Promise<void>
```

| Param         | Type                                                 |
| ------------- | ---------------------------------------------------- |
| **`options`** | <code>{ sessionId: string; force?: boolean; }</code> |

--------------------


### completeWebSheetAction(...)

```typescript
completeWebSheetAction(options: { sheetId: string; requestId: number; result?: Record<string, unknown>; error?: string; }) => Promise<void>
```

Reply only to an action from the currently presented sheet.

| Param         | Type                                                                                                                               |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **`options`** | <code>{ sheetId: string; requestId: number; result?: <a href="#record">Record</a>&lt;string, unknown&gt;; error?: string; }</code> |

--------------------


### presentActionSheet(...)

```typescript
presentActionSheet(options: Omit<NativeDialogOptions, 'style'>) => Promise<NativeDialogResult>
```

Present the app document in an isolated UIKit sheet; resolves on dismissal.

| Param         | Type                                                                                                         |
| ------------- | ------------------------------------------------------------------------------------------------------------ |
| **`options`** | <code><a href="#omit">Omit</a>&lt;<a href="#nativedialogoptions">NativeDialogOptions</a>, 'style'&gt;</code> |

**Returns:** <code>Promise&lt;<a href="#nativedialogresult">NativeDialogResult</a>&gt;</code>

--------------------


### presentDialog(...)

```typescript
presentDialog(options: NativeDialogOptions) => Promise<NativeDialogResult>
```

| Param         | Type                                                                |
| ------------- | ------------------------------------------------------------------- |
| **`options`** | <code><a href="#nativedialogoptions">NativeDialogOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#nativedialogresult">NativeDialogResult</a>&gt;</code>

--------------------


### dismissDialog(...)

```typescript
dismissDialog(options: { id: string; }) => Promise<{ dismissed: boolean; }>
```

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: string; }</code> |

**Returns:** <code>Promise&lt;{ dismissed: boolean; }&gt;</code>

--------------------


### presentWebSheet(...)

```typescript
presentWebSheet(options: NativeWebSheetOptions) => Promise<{ role: 'close' | 'gesture'; }>
```

| Param         | Type                                                                    |
| ------------- | ----------------------------------------------------------------------- |
| **`options`** | <code><a href="#nativewebsheetoptions">NativeWebSheetOptions</a></code> |

**Returns:** <code>Promise&lt;{ role: 'close' | 'gesture'; }&gt;</code>

--------------------


### addListener('onTopToolbarLayoutChange', ...)

```typescript
addListener(eventName: 'onTopToolbarLayoutChange', listenerFunc: (layout: { placement: 'hidden' | 'top' | 'left' | 'right'; verticalEdge: 'none' | 'left' | 'right'; topInset?: number; }) => void) => Promise<PluginListenerHandle>
```

Register before initialize/createTabBar to receive the first adaptive layout.

| Param              | Type                                                                                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **`eventName`**    | <code>'onTopToolbarLayoutChange'</code>                                                                                                                |
| **`listenerFunc`** | <code>(layout: { placement: 'hidden' \| 'top' \| 'left' \| 'right'; verticalEdge: 'left' \| 'right' \| 'none'; topInset?: number; }) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('onTabBarLayoutChange', ...)

```typescript
addListener(eventName: 'onTabBarLayoutChange', listenerFunc: (layout: TabBarLayout) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                       |
| ------------------ | -------------------------------------------------------------------------- |
| **`eventName`**    | <code>'onTabBarLayoutChange'</code>                                        |
| **`listenerFunc`** | <code>(layout: <a href="#tabbarlayout">TabBarLayout</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener(string, ...)

```typescript
addListener(eventName: string, listenerFunc: ListenerCallback) => Promise<PluginListenerHandle>
```

| Param              | Type                                                          |
| ------------------ | ------------------------------------------------------------- |
| **`eventName`**    | <code>string</code>                                           |
| **`listenerFunc`** | <code><a href="#listenercallback">ListenerCallback</a></code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### beginTopToolbarTransition(...)

```typescript
beginTopToolbarTransition(options: TopToolbarTransition) => Promise<{ duration: number; timing: 'native'; topInset?: number; }>
```

| Param         | Type                                                                  |
| ------------- | --------------------------------------------------------------------- |
| **`options`** | <code><a href="#toptoolbartransition">TopToolbarTransition</a></code> |

**Returns:** <code>Promise&lt;{ duration: number; timing: 'native'; topInset?: number; }&gt;</code>

--------------------


### updateTopToolbarTransition(...)

```typescript
updateTopToolbarTransition(options: { id: number; progress: number; }) => Promise<void>
```

Compatibility entry point; native timing mode keeps UIKit in control of its morph spring.

| Param         | Type                                           |
| ------------- | ---------------------------------------------- |
| **`options`** | <code>{ id: number; progress: number; }</code> |

--------------------


### finishTopToolbarTransition(...)

```typescript
finishTopToolbarTransition(options: { id: number; completed: boolean; }) => Promise<void>
```

| Param         | Type                                             |
| ------------- | ------------------------------------------------ |
| **`options`** | <code>{ id: number; completed: boolean; }</code> |

--------------------


### initialize()

```typescript
initialize() => Promise<void>
```

--------------------


### reRender()

```typescript
reRender() => Promise<void>
```

--------------------


### createTabBar(...)

```typescript
createTabBar(options: CreateTabBar) => Promise<void>
```

| Param         | Type                                                  |
| ------------- | ----------------------------------------------------- |
| **`options`** | <code><a href="#createtabbar">CreateTabBar</a></code> |

--------------------


### removeTabs()

```typescript
removeTabs() => Promise<void>
```

--------------------


### createToolbar(...)

```typescript
createToolbar(options: CreateOrSetToolbar) => Promise<void>
```

| Param         | Type                                                              |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code><a href="#createorsettoolbar">CreateOrSetToolbar</a></code> |

--------------------


### createTopToolbar(...)

```typescript
createTopToolbar(options: CreateOrSetToolbar) => Promise<void>
```

| Param         | Type                                                              |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code><a href="#createorsettoolbar">CreateOrSetToolbar</a></code> |

--------------------


### setToolbarItems(...)

```typescript
setToolbarItems(options: CreateOrSetToolbar) => Promise<void>
```

| Param         | Type                                                              |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code><a href="#createorsettoolbar">CreateOrSetToolbar</a></code> |

--------------------


### setTopToolbarItems(...)

```typescript
setTopToolbarItems(options: CreateOrSetToolbar) => Promise<void>
```

| Param         | Type                                                              |
| ------------- | ----------------------------------------------------------------- |
| **`options`** | <code><a href="#createorsettoolbar">CreateOrSetToolbar</a></code> |

--------------------


### showTabBar()

```typescript
showTabBar() => Promise<void>
```

--------------------


### hideTabBar()

```typescript
hideTabBar() => Promise<void>
```

--------------------


### showSearch()

```typescript
showSearch() => Promise<void>
```

--------------------


### hideSearch()

```typescript
hideSearch() => Promise<void>
```

--------------------


### showToolbar()

```typescript
showToolbar() => Promise<void>
```

--------------------


### hideToolbar()

```typescript
hideToolbar() => Promise<void>
```

--------------------


### showTopToolbar()

```typescript
showTopToolbar() => Promise<void>
```

--------------------


### hideTopToolbar()

```typescript
hideTopToolbar() => Promise<void>
```

--------------------


### tabBarSelected()

```typescript
tabBarSelected() => Promise<{ value: number | undefined; }>
```

**Returns:** <code>Promise&lt;{ value: number; }&gt;</code>

--------------------


### Interfaces


#### NativeToastOptions

| Prop                  | Type                             |
| --------------------- | -------------------------------- |
| **`id`**              | <code>string</code>              |
| **`header`**          | <code>string</code>              |
| **`message`**         | <code>string</code>              |
| **`duration`**        | <code>number</code>              |
| **`swipeGesture`**    | <code>boolean</code>             |
| **`backgroundColor`** | <code>string</code>              |
| **`textColor`**       | <code>string</code>              |
| **`messageColor`**    | <code>string</code>              |
| **`buttons`**         | <code>{ text: string; }[]</code> |


#### NativeDialogResult

| Prop           | Type                |
| -------------- | ------------------- |
| **`buttonId`** | <code>string</code> |
| **`role`**     | <code>string</code> |


#### NativeDialogOptions

| Prop                  | Type                                                                                                                                  | Description                                                    |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **`sourceItemTag`**   | <code>number</code>                                                                                                                   | Tag of the real native toolbar item that initiated this sheet. |
| **`source`**          | <code><a href="#nativeactionsheetsource">NativeActionSheetSource</a></code>                                                           |                                                                |
| **`id`**              | <code>string</code>                                                                                                                   |                                                                |
| **`style`**           | <code>'alert' \| 'actionSheet'</code>                                                                                                 |                                                                |
| **`appearance`**      | <code>'automatic' \| 'light' \| 'dark'</code>                                                                                         |                                                                |
| **`title`**           | <code>string</code>                                                                                                                   |                                                                |
| **`message`**         | <code>string</code>                                                                                                                   |                                                                |
| **`tintColor`**       | <code>string</code>                                                                                                                   |                                                                |
| **`backdropDismiss`** | <code>boolean</code>                                                                                                                  |                                                                |
| **`buttons`**         | <code>{ id: string; title: string; role?: 'default' \| 'cancel' \| 'destructive'; preferred?: boolean; disabled?: boolean; }[]</code> |                                                                |


#### NativeActionSheetSource

| Prop                 | Type                |
| -------------------- | ------------------- |
| **`x`**              | <code>number</code> |
| **`y`**              | <code>number</code> |
| **`width`**          | <code>number</code> |
| **`height`**         | <code>number</code> |
| **`viewportWidth`**  | <code>number</code> |
| **`viewportHeight`** | <code>number</code> |


#### NativeWebSheetOptions

| Prop                        | Type                                                             | Description                                                                     |
| --------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **`backgroundColor`**       | <code>string</code>                                              | Consumer-owned colors (#RRGGBB or #RRGGBBAA); no palette is imposed.            |
| **`headerBackgroundColor`** | <code>string</code>                                              |                                                                                 |
| **`headerTranslucent`**     | <code>boolean</code>                                             |                                                                                 |
| **`closeButtonVisible`**    | <code>boolean</code>                                             |                                                                                 |
| **`detents`**               | <code>('medium' \| 'large')[]</code>                             |                                                                                 |
| **`initialDetent`**         | <code>'medium' \| 'large'</code>                                 |                                                                                 |
| **`sessionId`**             | <code>string</code>                                              | Opaque transport identity, unrelated to the document's business data.           |
| **`appearance`**            | <code>'automatic' \| 'light' \| 'dark'</code>                    |                                                                                 |
| **`tintColor`**             | <code>string</code>                                              |                                                                                 |
| **`grabberVisible`**        | <code>boolean</code>                                             |                                                                                 |
| **`dismissible`**           | <code>boolean</code>                                             |                                                                                 |
| **`notifyBeforeClose`**     | <code>boolean</code>                                             | Notify the document before closing; never blocks past closeTimeout.             |
| **`closeTimeout`**          | <code>number</code>                                              | Maximum grace period in milliseconds (500–10000, default 3000).                 |
| **`title`**                 | <code>string</code>                                              |                                                                                 |
| **`closeTitle`**            | <code>string</code>                                              |                                                                                 |
| **`data`**                  | <code><a href="#record">Record</a>&lt;string, unknown&gt;</code> | Data injected before the isolated document starts. No authentication is copied. |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### TabBarLayout

Extra tab/sidebar occlusion after subtracting the system safe area. Values are UIKit points (CSS pixels at viewport scale 1).

| Prop            | Type                                                                         |
| --------------- | ---------------------------------------------------------------------------- |
| **`placement`** | <code>'hidden' \| 'bottom' \| 'top' \| 'left' \| 'right' \| 'sidebar'</code> |
| **`insets`**    | <code>{ top: number; right: number; bottom: number; left: number; }</code>   |


#### TopToolbarTransition

| Prop            | Type                                                              | Description                                                                              |
| --------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **`id`**        | <code>number</code>                                               |                                                                                          |
| **`from`**      | <code><a href="#createorsettoolbar">CreateOrSetToolbar</a></code> |                                                                                          |
| **`to`**        | <code><a href="#createorsettoolbar">CreateOrSetToolbar</a></code> |                                                                                          |
| **`direction`** | <code>'forward' \| 'back'</code>                                  |                                                                                          |
| **`duration`**  | <code>number</code>                                               | Requested duration in milliseconds; UIKit reports the duration of its native transition. |


#### CreateOrSetToolbar

| Prop          | Type                                                                                                        |
| ------------- | ----------------------------------------------------------------------------------------------------------- |
| **`items`**   | <code><a href="#toolbaritem">ToolbarItem</a>&lt;<a href="#toolbaritemtype">ToolbarItemType</a>&gt;[]</code> |
| **`options`** | <code><a href="#toolbaroptions">ToolbarOptions</a></code>                                                   |


#### ToolbarItem

| Prop       | Type                            |
| ---------- | ------------------------------- |
| **`type`** | <code>T</code>                  |
| **`data`** | <code>ToolbarItemData[T]</code> |


#### ToolbarItemData

| Prop                                  | Type                                                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`[ToolbarItemType.Button]`**        | <code>{ identifier?: string; tag: number; enabled?: boolean; image?: string; title?: string; style?: <a href="#toolbarbuttonitemstyle">ToolbarButtonItemStyle</a>; tintColor?: string; tintColorDark?: string; }</code>                                                                                                                                                                               |
| **`[ToolbarItemType.FlexibleSpace]`** | <code>void</code>                                                                                                                                                                                                                                                                                                                                                                                     |
| **`[ToolbarItemType.Menu]`**          | <code>{ identifier?: string; enabled?: boolean; image?: string; title?: string; menuTitle?: string; subtitle?: string; subtitleTintColor?: string; axisBehavior?: 'automatic' \| 'horizontalOnly' \| 'verticalPreferred'; tintColor?: string; tintColorDark?: string; items: <a href="#toolbarmenuitem">ToolbarMenuItem</a>&lt;<a href="#toolbarmenuitemtype">ToolbarMenuItemType</a>&gt;[]; }</code> |


#### ToolbarMenuItem

| Prop       | Type                                |
| ---------- | ----------------------------------- |
| **`type`** | <code>T</code>                      |
| **`data`** | <code>ToolbarMenuItemData[T]</code> |


#### ToolbarMenuItemData

| Prop                                  | Type                                                                                                                                                                          |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`[ToolbarMenuItemType.Action]`**    | <code>{ identifier: string; checked?: boolean; attributes?: ToolbarMenuItemAttributes[]; title?: string; image?: string; tintColor?: string; tintColorDark?: string; }</code> |
| **`[ToolbarMenuItemType.Separator]`** | <code>void</code>                                                                                                                                                             |


#### ToolbarOptions

| Prop                        | Type                                                       | Description                                                                                                |
| --------------------------- | ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **`transparentBackground`** | <code>boolean</code>                                       | Clear the navigation bar canvas while preserving the system Glass item backgrounds.                        |
| **`appearance`**            | <code>'automatic' \| 'light' \| 'dark'</code>              | Native material scheme of the destination web header, applied at willShow.                                 |
| **`tabBarVisible`**         | <code>boolean</code>                                       | Destination tab visibility, committed with the page transition and restored on cancellation.               |
| **`visible`**               | <code>boolean</code>                                       | Commit visibility together with items, avoiding a hide/show gap.                                           |
| **`animated`**              | <code>boolean</code>                                       | Animate an item change, respecting the system Reduce Motion setting.                                       |
| **`adaptive`**              | <code>boolean</code>                                       | Use UINavigationController-managed bars so UIKit adapts them to iPhone Duo.                                |
| **`imageBasePath`**         | <code>string</code>                                        |                                                                                                            |
| **`position`**              | <code>{ top: number; left: number; right: number; }</code> | Non-adaptive top-toolbar offsets from the WebView edges, in UIKit points. Used for centered modal headers. |


#### CreateTabBar

| Prop                | Type                                                    |
| ------------------- | ------------------------------------------------------- |
| **`items`**         | <code>TabBarItem[]</code>                               |
| **`options`**       | <code><a href="#tabbaroptions">TabBarOptions</a></code> |
| **`searchBarItem`** | <code><a href="#searchbaritem">SearchBarItem</a></code> |


#### TabBarItem

| Prop                | Type                |
| ------------------- | ------------------- |
| **`title`**         | <code>string</code> |
| **`tag`**           | <code>number</code> |
| **`image`**         | <code>string</code> |
| **`imageSelected`** | <code>string</code> |


#### TabBarOptions

| Prop                              | Type                                  | Description                                                                                  |
| --------------------------------- | ------------------------------------- | -------------------------------------------------------------------------------------------- |
| **`placement`**                   | <code>'sidebar' \| 'automatic'</code> | Let UIKit adapt to the display/pose, or prefer a sidebar when supported (iOS 27+ on iPhone). |
| **`hasSearchBar`**                | <code>boolean</code>                  |                                                                                              |
| **`selectedTag`**                 | <code>number</code>                   |                                                                                              |
| **`fontSize`**                    | <code>number</code>                   |                                                                                              |
| **`unselectedFontSize`**          | <code>number</code>                   |                                                                                              |
| **`tintColor`**                   | <code>string</code>                   |                                                                                              |
| **`fontColor`**                   | <code>string</code>                   |                                                                                              |
| **`unselectedFontColor`**         | <code>string</code>                   |                                                                                              |
| **`unselectedItemTintColor`**     | <code>string</code>                   |                                                                                              |
| **`fontColorDark`**               | <code>string</code>                   |                                                                                              |
| **`unselectedFontColorDark`**     | <code>string</code>                   |                                                                                              |
| **`tintColorDark`**               | <code>string</code>                   |                                                                                              |
| **`unselectedItemTintColorDark`** | <code>string</code>                   |                                                                                              |
| **`imageBasePath`**               | <code>string</code>                   |                                                                                              |


#### SearchBarItem

| Prop              | Type                |
| ----------------- | ------------------- |
| **`placeholder`** | <code>string</code> |


### Type Aliases


#### Record

Construct a type with a set of properties K of type T

<code>{ [P in K]: T; }</code>


#### Omit

Construct a type with the properties of T except for those in type K.

<code><a href="#pick">Pick</a>&lt;T, <a href="#exclude">Exclude</a>&lt;keyof T, K&gt;&gt;</code>


#### Pick

From T, pick a set of properties whose keys are in the union K

<code>{ [P in K]: T[P]; }</code>


#### Exclude

<a href="#exclude">Exclude</a> from T those types that are assignable to U

<code>T extends U ? never : T</code>


#### ListenerCallback

<code>(err: any, ...args: any[]): void</code>


### Enums


#### ToolbarButtonItemStyle

| Members         | Value          |
| --------------- | -------------- |
| **`Plain`**     | <code>0</code> |
| **`Prominent`** |                |


#### ToolbarMenuItemAttributes

| Members                  | Value          |
| ------------------------ | -------------- |
| **`KeepsMenuPresented`** | <code>0</code> |
| **`Destructive`**        |                |
| **`Disabled`**           |                |
| **`Hidden`**             |                |


#### ToolbarMenuItemType

| Members         | Value          |
| --------------- | -------------- |
| **`Action`**    | <code>0</code> |
| **`Separator`** |                |


#### ToolbarItemType

| Members             | Value          |
| ------------------- | -------------- |
| **`Button`**        | <code>0</code> |
| **`FlexibleSpace`** |                |
| **`Menu`**          |                |

</docgen-api>
