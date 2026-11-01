# Native web sheets

`presentWebSheet` hosts the app's document in an isolated WKWebView. Its `data`
object is opaque: the plugin only injects it as `window.__nativeWebSheet`.
The application owns rendering, validation, authentication and action handlers.

Presentation options include an opaque `sessionId`, title, localized close label,
appearance, tint, grabber visibility and interactive dismissal.
`closeButtonVisible` controls the close affordance; `detents` accepts `medium`
and/or `large`, and `initialDetent` selects the initial size.
`onWebSheetPresent` emits `{ sessionId, sheetId }` after UIKit presentation
completes. The `presentWebSheet` promise resolves on dismissal, not presentation. The application
posts `{ type: 'ready', backgroundColor: '#rrggbb' }` when its document is ready.

## Request/reply transport

The document posts messages through
`window.webkit.messageHandlers.nativeWebSheet.postMessage(...)`.

- `{ type: 'action', requestId, action, data }` emits `onWebSheetAction` to the
  owning application. Action names and JSON objects are not interpreted.
- The application responds using `completeWebSheetAction({ sheetId, requestId,
  result, error })`. The document receives `native-web-sheet-result`, whose
  CustomEvent detail contains the correlated result or error.
- `{ type: 'error', message }` emits `onWebSheetError` after readiness. A rendering
  error before readiness rejects presentation instead.
- `{ type: 'confirm', requestId, title, message, confirmTitle, cancelTitle }`
  presents a native confirmation and replies with `{ confirmed }`.
- `{ type: 'share', requestId, title, message, url }` explicitly opens the system
  share controller and replies with `{ shared }`. Ordinary action results never
  trigger native UI implicitly.

Events carry the presentation's `sessionId`; replies are accepted only for the
currently owned `sheetId`. Hosts must whitelist their own action handlers and
validate data in the application.

## Closing

Without `notifyBeforeClose`, the close button dismisses immediately. With it, the
plugin dispatches `native-web-sheet-close-request` and waits for `{ type: 'close' }`.
Pending requests or errors never veto that acknowledgement. A native watchdog
closes after `closeTimeout` milliseconds (default 3000, bounded to 500–10000),
and a second close-button tap forces dismissal immediately. The close button
remains enabled throughout. A JavaScript evaluation error also dismisses.

The host may call `dismissWebSheet({ sessionId, force })` for programmatic closing.
A stale session cannot dismiss a newer presentation.

Send action messages only after the ready message; applications may queue initial
loading requests until readiness. Programmatic closing also works before the
controller has finished presenting.

The close button occupies the leading navigation slot. Documents may send
`{ type: "headerActions", actions: [{ id, title, disabled }] }` to configure
trailing native buttons. Taps dispatch `native-web-sheet-header-action` with
`CustomEvent.detail.id` to the isolated document. An empty array removes them.
The plugin treats action identifiers as opaque strings.

On iOS 27.1 and later, sheets opt into a horizontal header using
`preferredVerticalBarBehavior = .disabled`, preserving leading dismissal and
trailing actions on devices with a vertical navigation bar.

## Consumer-owned appearance

`backgroundColor`, `headerBackgroundColor`, `tintColor` accept `#RRGGBB` or
`#RRGGBBAA`. `headerTranslucent` enables the native blur. These options may be
provided to `presentWebSheet` and in the document's ready message. Body and safe
areas use `backgroundColor`; the header uses `headerBackgroundColor`, falling
back to that same background when omitted. The plugin preserves alpha and does
not impose a palette or reduce opacity. Send explicit alpha for a translucent
header color. A ready message may override initial presentation colors.

## Native dialogs

`presentDialog({ id, style, title, message, appearance, tintColor, buttons })`
presents a UIKit alert or action sheet above the visible controller, including
a web sheet. Buttons carry opaque IDs, titles, semantic roles, enabled state and
an optional preferred flag. `onDialogPresent` reports the ID after presentation;
the promise resolves after dismissal with `{ buttonId?, role }`.
`dismissDialog({ id })` only closes the matching presentation. The host owns
serialization, action handlers and fallback behavior. No executable handlers or
business data are interpreted by the plugin.

Popover action sheets can omit the cancel button; an outside tap remains the
cancel action when such a button was configured. The plugin does not replace
UIAlertController's private presentation delegate.

The isolated web viewport is constrained to the controller's safe area below
the navigation bar. Its outer scroll view cannot scroll or bounce; document
content may scroll in its own inner containers. `--native-sheet-header-height`
is zero because the native header is already excluded from the viewport.

`presentActionSheet(options)` is the dedicated action-sheet entry point. It
forces UIKit `.actionSheet` even if a caller supplies a different style, and
uses the initiating control as the source for inline presentations. It uses the same
`onDialogPresent`, result and dismissal transport. Generic `presentDialog` now
requires an explicit valid style; it never defaults a missing style to alert.

## Inline action-sheet source

Pass `source: { x, y, width, height, viewportWidth, viewportHeight }` using the
initiating web control's viewport bounds. The native presenter creates a small
noninteractive source view in the active WKWebView at those bounds, instead of
using the entire controller as the source. Anchored sheets use an arrowless
presentation and implicit cancel, with no custom background or button drawing.
The same source payload is accepted by isolated documents' `confirm` messages.

Native toolbar callers should pass `sourceItemTag` instead of web coordinates.
The action-sheet presenter resolves that tag to the existing `UIBarButtonItem`
and assigns it to `popoverPresentationController.sourceItem`, preserving the
system's inline transition. An unknown or expired tag rejects presentation; it
is never replaced with a centered anchor. Toolbar button events retain the same
opaque tag, so the consumer owns the association between action and source.
