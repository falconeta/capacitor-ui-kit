# capacitor-ui-kit

plugin that opens the gate to using iOS UIKit in the Capacitor ecosystem

## Install

```bash
npm install capacitor-ui-kit
npx cap sync
```

## API

<docgen-index>

* [`createTabBar(...)`](#createtabbar)
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
* [Interfaces](#interfaces)
* [Enums](#enums)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### createTabBar(...)

```typescript
createTabBar(options: CreateTabBar) => Promise<void>
```

| Param         | Type                                                  |
| ------------- | ----------------------------------------------------- |
| **`options`** | <code><a href="#createtabbar">CreateTabBar</a></code> |

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


### Interfaces


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

| Prop                              | Type                |
| --------------------------------- | ------------------- |
| **`selectedTag`**                 | <code>number</code> |
| **`fontSize`**                    | <code>number</code> |
| **`unselectedFontSize`**          | <code>number</code> |
| **`tintColor`**                   | <code>string</code> |
| **`fontColor`**                   | <code>string</code> |
| **`unselectedFontColor`**         | <code>string</code> |
| **`unselectedItemTintColor`**     | <code>string</code> |
| **`fontColorDark`**               | <code>string</code> |
| **`unselectedFontColorDark`**     | <code>string</code> |
| **`tintColorDark`**               | <code>string</code> |
| **`unselectedItemTintColorDark`** | <code>string</code> |
| **`imageBasePath`**               | <code>string</code> |


#### SearchBarItem

| Prop              | Type                |
| ----------------- | ------------------- |
| **`placeholder`** | <code>string</code> |


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

| Prop                                  | Type                                                                                                                                                                                        |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`[ToolbarItemType.Button]`**        | <code>{ tag: number; image?: string; title?: string; style?: <a href="#toolbarbuttonitemstyle">ToolbarButtonItemStyle</a>; tintColor?: string; }</code>                                     |
| **`[ToolbarItemType.FlexibleSpace]`** | <code>void</code>                                                                                                                                                                           |
| **`[ToolbarItemType.Menu]`**          | <code>{ image?: string; title?: string; menuTitle?: string; items: <a href="#toolbarmenuitem">ToolbarMenuItem</a>&lt;<a href="#toolbarmenuitemtype">ToolbarMenuItemType</a>&gt;[]; }</code> |


#### ToolbarMenuItem

| Prop       | Type                                |
| ---------- | ----------------------------------- |
| **`type`** | <code>T</code>                      |
| **`data`** | <code>ToolbarMenuItemData[T]</code> |


#### ToolbarMenuItemData

| Prop                                  | Type                                                                                                           |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **`[ToolbarMenuItemType.Action]`**    | <code>{ identifier: string; attributes?: ToolbarMenuItemAttributes[]; title?: string; image?: string; }</code> |
| **`[ToolbarMenuItemType.Separator]`** | <code>void</code>                                                                                              |


#### ToolbarOptions

| Prop                | Type                |
| ------------------- | ------------------- |
| **`imageBasePath`** | <code>string</code> |


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
