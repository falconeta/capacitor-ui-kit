import type { ListenerCallback, Plugin, PluginListenerHandle } from '@capacitor/core';

export interface TabBarItem {
  title: string;
  tag: number;
  image?: string;
  imageSelected?: string;
}

export interface SearchBarItem {
  placeholder: string;
}

/** Extra tab/sidebar occlusion after subtracting the system safe area. Values are UIKit points (CSS pixels at viewport scale 1). */
export interface TabBarLayout {
  placement: 'hidden' | 'bottom' | 'top' | 'left' | 'right' | 'sidebar';
  insets: { top: number; right: number; bottom: number; left: number };
}

export interface TabBarOptions {
  /** Let UIKit adapt to the display/pose, or prefer a sidebar when supported (iOS 27+ on iPhone). */
  placement?: 'automatic' | 'sidebar';
  hasSearchBar: boolean;
  selectedTag: number;
  fontSize: number;
  unselectedFontSize: number;
  tintColor: string;
  fontColor: string;
  unselectedFontColor: string;
  unselectedItemTintColor: string;
  fontColorDark?: string;
  unselectedFontColorDark?: string;
  tintColorDark?: string;
  unselectedItemTintColorDark?: string;
  imageBasePath?: string;
}

export interface CreateTabBar {
  items: TabBarItem[];
  options: TabBarOptions;
  searchBarItem?: SearchBarItem;
}

export enum ToolbarItemType {
  Button = 0,
  FlexibleSpace,
  Menu,
}

export enum ToolbarMenuItemType {
  Action = 0,
  Separator,
}

export enum ToolbarButtonItemStyle {
  Plain = 0,
  Prominent,
}
export enum ToolbarMenuItemAttributes {
  KeepsMenuPresented = 0,
  Destructive,
  Disabled,
  Hidden,
}

export interface ToolbarItem<T extends ToolbarItemType> {
  type: T;
  data: ToolbarItemData[T];
}

export interface ToolbarMenuItem<T extends ToolbarMenuItemType> {
  type: T;
  data: ToolbarMenuItemData[T];
}

export interface ToolbarMenuItemData {
  [ToolbarMenuItemType.Action]: {
    identifier: string;
    /** Show the current selection using UIKit's native checkmark. */
    checked?: boolean;
    attributes?: ToolbarMenuItemAttributes[];
    title?: string;
    image?: string;
    tintColor?: string;
    tintColorDark?: string;
  };
  [ToolbarMenuItemType.Separator]: void;
}

export interface ToolbarItemData {
  [ToolbarItemType.Button]: {
    /** Stable identity for UIKit morphing across page configurations. */
    identifier?: string;
    tag: number;
    enabled?: boolean;
    image?: string;
    title?: string;
    style?: ToolbarButtonItemStyle;
    tintColor?: string;
    tintColorDark?: string;
  };
  [ToolbarItemType.FlexibleSpace]: void;
  [ToolbarItemType.Menu]: {
    /** Stable identity for UIKit morphing across page configurations. */
    identifier?: string;
    enabled?: boolean;
    image?: string;
    title?: string;
    menuTitle?: string;
    tintColor?: string;
    tintColorDark?: string;
    items: ToolbarMenuItem<ToolbarMenuItemType>[];
  };
}

export interface ToolbarOptions {
  /** Native material scheme of the destination web header, applied at willShow. */
  appearance?: 'automatic' | 'light' | 'dark';
  /** Destination tab visibility, committed with the page transition and restored on cancellation. */
  tabBarVisible?: boolean;
  /** Commit visibility together with items, avoiding a hide/show gap. */
  visible?: boolean;
  /** Animate an item change, respecting the system Reduce Motion setting. */
  animated?: boolean;
  /** Use UINavigationController-managed bars so UIKit adapts them to iPhone Duo. */
  adaptive?: boolean;
  imageBasePath?: string;
  /** Non-adaptive top-toolbar offsets from the WebView edges, in UIKit points. Used for centered modal headers. */
  position?: { top: number; left: number; right: number };
}

export interface CreateOrSetToolbar {
  items: ToolbarItem<ToolbarItemType>[];
  options: ToolbarOptions;
}

export interface TopToolbarTransition {
  id: number;
  from: CreateOrSetToolbar;
  to: CreateOrSetToolbar;
  direction: 'forward' | 'back';
  /** Requested duration in milliseconds; UIKit reports the duration of its native transition. */
  duration: number;
}

export interface CapacitorUIKitPlugin extends Plugin {
  /** Register before initialize/createTabBar to receive the first adaptive layout. */
  addListener(eventName: 'onTopToolbarLayoutChange', listenerFunc: (layout: { placement: 'hidden' | 'top' | 'left' | 'right'; verticalEdge: 'none' | 'left' | 'right' }) => void): Promise<PluginListenerHandle>;
  addListener(eventName: 'onTabBarLayoutChange', listenerFunc: (layout: TabBarLayout) => void): Promise<PluginListenerHandle>;
  addListener(eventName: string, listenerFunc: ListenerCallback): Promise<PluginListenerHandle>;
  beginTopToolbarTransition(options: TopToolbarTransition): Promise<{ duration: number; timing: 'native' }>;
  /** Compatibility entry point; native timing mode keeps UIKit in control of its morph spring. */
  updateTopToolbarTransition(options: { id: number; progress: number }): Promise<void>;
  finishTopToolbarTransition(options: { id: number; completed: boolean }): Promise<void>;
  initialize(): Promise<void>;
  reRender(): Promise<void>;
  createTabBar(options: CreateTabBar): Promise<void>;
  removeTabs(): Promise<void>;
  createToolbar(options: CreateOrSetToolbar): Promise<void>;
  createTopToolbar(options: CreateOrSetToolbar): Promise<void>;
  setToolbarItems(options: CreateOrSetToolbar): Promise<void>;
  setTopToolbarItems(options: CreateOrSetToolbar): Promise<void>;
  showTabBar(): Promise<void>;
  hideTabBar(): Promise<void>;
  showSearch(): Promise<void>;
  hideSearch(): Promise<void>;
  showToolbar(): Promise<void>;
  hideToolbar(): Promise<void>;
  showTopToolbar(): Promise<void>;
  hideTopToolbar(): Promise<void>;
  tabBarSelected(): Promise<{ value: number | undefined }>;
}
