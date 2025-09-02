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
* [`showTabBar()`](#showtabbar)
* [`hideTabBar()`](#hidetabbar)
* [Interfaces](#interfaces)

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


### Interfaces


#### CreateTabBar

| Prop          | Type                                                    |
| ------------- | ------------------------------------------------------- |
| **`items`**   | <code>TabBarItem[]</code>                               |
| **`options`** | <code><a href="#tabbaroptions">TabBarOptions</a></code> |


#### TabBarItem

| Prop                | Type                |
| ------------------- | ------------------- |
| **`title`**         | <code>string</code> |
| **`tag`**           | <code>number</code> |
| **`image`**         | <code>string</code> |
| **`imageSelected`** | <code>string</code> |


#### TabBarOptions

| Prop                          | Type                |
| ----------------------------- | ------------------- |
| **`selectedTag`**             | <code>number</code> |
| **`tintColor`**               | <code>string</code> |
| **`fontColor`**               | <code>string</code> |
| **`fontSize`**                | <code>number</code> |
| **`unselectedFontSize`**      | <code>number</code> |
| **`unselectedFontColor`**     | <code>string</code> |
| **`unselectedItemTintColor`** | <code>string</code> |
| **`imageBasePath`**           | <code>string</code> |

</docgen-api>
