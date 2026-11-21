# Appearance

ModernOS takes its colors from your wallpaper. Change the picture and the whole desktop, from the bar to your terminal and browser, changes with it. This chapter explains how that works and which knobs you have.

The options live in Settings under **Design** (Design). Open Settings with **SUPER + I**. Labels are given in English with the German label in parentheses. You can change the language under **Language & Time** (Sprache & Zeit).

## Colors from your wallpaper

ModernOS follows the Material You idea: it looks at your wallpaper, picks a main color from it, and builds a complete, matching set of colors from that one color. Buttons, panels, highlights, text and window borders all come from this set, so everything stays readable and fits together.

This happens automatically every time you set a new wallpaper.

### Light and dark

Under **System colors** (Systemfarben), **Light and dark** (Hell und dunkel) switches between **Dark** (Dunkel) and **Light** (Hell). Both are built from the same wallpaper.

### Color variants

**Color variant** (Farbvariante) shows a row of cards. Each card is a different way of turning your wallpaper into colors, and shows three sample colors so you can compare before you choose.

The variants are Tonal spot (Tonal Spot), Expressive (Expressiv), Vibrant (Kräftig), Fidelity (Fidelity), Content (Inhalt), Fruit salad (Fruchtsalat), Rainbow (Regenbogen), Neutral (Neutral) and Monochrome (Monochrom). ModernOS starts with Tonal spot in dark mode. The easiest way to find your favourite is to look at the sample colors on each card.

Click a card to apply it. The cards are recreated whenever you pick a new wallpaper or switch between light and dark.

When you pick a card, ModernOS keeps the main color shown on that card. When you later pick a new wallpaper, the colors follow the new picture again.

### Color brightness

Under **Wallpaper** (Hintergrundbild), **Color brightness** (Farbhelligkeit) lightens surfaces, buttons and icons with the wallpaper color. Higher is brighter. Use it if the desktop feels too dark or too grey for your taste.

### Theme profiles, contrast and fixed colors

Behind the scenes, each look is stored as a theme profile. Besides light, dark and the variant, a profile can also ask for higher contrast, or use one fixed brand color instead of the wallpaper. ModernOS ships a few such profiles, for example a high-contrast one and a fixed purple one.

The Design page only offers light, dark and the variant cards. Contrast and fixed colors are an advanced feature without a switch in Settings. Technical details are in [Theming](../THEMING.md).

## Wallpapers

### Choosing a wallpaper in Settings

At the top of the Design page you see your current wallpaper and a few random suggestions from your library. Click a suggestion to apply it. **Browse wallpapers** (Hintergründe durchsuchen) opens the wallpaper picker.

### The wallpaper picker

Press **SUPER + W** to open the picker, titled **Wallpapers** (Hintergründe).

- Use the arrow keys and press **Enter**, or simply click a picture, to apply it.
- **Esc** closes the picker.
- **Add** (Hinzufügen) lets you choose an image from your files and adds it to your library.
- **Get wallpapers** (Hintergründe holen) opens the wallpaper website in its own window. Pictures you download there go straight into your wallpaper folder, and you see "Wallpaper saved". If that window cannot open, the site opens in your browser instead; then save the pictures into your wallpaper folder yourself.
- **Open folder** (Ordner öffnen) shows your wallpaper folder in Files.
- To remove a picture, use the delete button on its tile and confirm **Delete wallpaper?**. The pictures that come with ModernOS and the wallpaper you are currently using cannot be deleted.

Your own wallpapers live in `~/Pictures/Wallpapers`. The picker also shows the wallpapers that come with ModernOS. The newest pictures are shown first. JPG, PNG and WebP images work.

### The online provider

The website used by **Get wallpapers** is set under **Wallpaper Provider** (Hintergrund-Anbieter) on the Design page. The default is `https://4kwallpapers.com`. You can type the address of another wallpaper site there.

### Wallpaper animation

**Wallpaper animation** (Hintergrund-Animation) decides how a new wallpaper appears:

- Fade (Überblenden)
- Grow (Wachsen)
- Wipe (Wischen)
- Wave (Welle)
- Outer (Nach innen)
- Grow (random) (Wachsen (zufällig))
- Instant fade (Sofort)
- Random (Zufällig), a different one each time

Choosing one plays it once so you can see it.

## Which apps follow your colors

| Where | When it changes |
|---|---|
| Bar, panels, launcher, notifications and all ModernOS apps | Immediately |
| Window borders | Immediately |
| kitty terminal | Immediately |
| Lock screen and login screen | They show your wallpaper and colors |
| Password prompts | The next time one opens |
| Vivaldi browser | Pages after reloading the tab; the browser frame after you close and reopen Vivaldi |
| GTK apps (most GNOME-style apps) | The next time you open the app |
| Qt and KDE apps | After you fully quit the app and open it again |

Vivaldi also receives a copy of your wallpaper for its own styling.

Corner rounding, font size and the cursor theme are passed on to GTK, Qt and Vivaldi as well, so other apps look consistent with the desktop.

## Fonts

ModernOS uses **Inter** for the interface and **JetBrains Mono** for terminals and code.

- **Font size** (Schriftgröße) on the Design page (and the same slider on the **Bar** page) makes all desktop text larger or smaller.
- The font families themselves cannot be changed in Settings.
- In the Texteditor you can switch to a fixed-width font from its View menu (see [Apps](09-apps.md)).

## Motion and animations

- **Animations** (Animationen) sets how long menus, the bar and windows take to move. **Off** (Aus) makes everything instant, **Default** (Standard) is normal, and **Slow** (Langsam) is calmer and easier to follow.
- **Wallpaper animation** controls only the wallpaper change, as described above.
- On slower computers, **Drop effects for speed** (Effekte für Tempo weglassen) under Settings > **Gaming** (Spiele) turns off blur, shadows and window wobble and makes panels solid. See [Gaming](12-gaming.md).

## Windows, corners and the cursor

The rest of the Design page shapes the look of windows:

- **Transparency** (Transparenz): how see-through panels and menus are.
- **Corner rounding** (Eckenrundung): rounder or squarer corners on windows, panels and buttons.
- **Window gaps** (Fensterabstände): space between windows (**Inner gaps**, Innere Abstände) and to the screen edge (**Outer gaps**, Äußere Abstände).
- **Window opacity** (Fensterdeckkraft): how solid app windows are.
- **Cursor theme** (Cursor-Thema) and **Cursor size** (Cursor-Größe).

Every option is described in [Settings](07-settings.md). For the bar and dock layout, see [The desktop](03-desktop.md).
