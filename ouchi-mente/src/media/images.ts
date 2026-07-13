import * as FileSystem from "expo-file-system/legacy";
import * as ImagePicker from "expo-image-picker";
import { newId } from "@/db/id";

/**
 * 写真は端末内（アプリのドキュメント領域の images/ 配下）にコピーして保存する。
 * 外部への送信は行わない。
 *
 * DBには「ファイル名のみ」を保存する。iOSではアプリ更新のたびに
 * ドキュメント領域の絶対パスが変わるため、絶対URIを保存すると
 * 更新後に写真の表示・削除ができなくなる。
 * （旧形式の file:// 絶対URIも表示だけは互換対応する）
 */

const IMAGE_DIR = `${FileSystem.documentDirectory}images/`;

const STORED_NAME_PATTERN = /^[a-z0-9-]+\.[a-z0-9]{1,5}$/;

/** DB保存値（ファイル名 or 旧形式の絶対URI）を表示用URIに変換する */
export function resolveImageUri(stored: string | undefined): string | undefined {
  if (!stored) return undefined;
  if (stored.startsWith("file://")) return stored; // 旧形式
  return `${IMAGE_DIR}${stored}`;
}

async function ensureImageDir(): Promise<void> {
  const info = await FileSystem.getInfoAsync(IMAGE_DIR);
  if (!info.exists) {
    await FileSystem.makeDirectoryAsync(IMAGE_DIR, { intermediates: true });
  }
}

/**
 * 写真ライブラリから1枚選び、アプリ内にコピーして保存名（ファイル名）を返す。
 * キャンセル時は undefined。
 */
export async function pickAndStoreImageAsync(): Promise<string | undefined> {
  const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
  if (!permission.granted) return undefined;

  const result = await ImagePicker.launchImageLibraryAsync({
    mediaTypes: "images",
    quality: 0.7,
    allowsEditing: false,
  });
  if (result.canceled || result.assets.length === 0) return undefined;

  await ensureImageDir();
  const source = result.assets[0].uri;
  // 拡張子はURI由来のため、英数字のみ・短いものだけ信用する
  const rawExtension = source.includes(".")
    ? source.slice(source.lastIndexOf(".") + 1).toLowerCase()
    : "";
  const extension = /^[a-z0-9]{1,5}$/.test(rawExtension) ? rawExtension : "jpg";
  const fileName = `${newId()}.${extension}`;
  await FileSystem.copyAsync({ from: source, to: `${IMAGE_DIR}${fileName}` });
  return fileName;
}

/** データ全削除用: アプリ内に保存したすべての写真を削除する */
export async function deleteAllStoredImagesAsync(): Promise<void> {
  try {
    const info = await FileSystem.getInfoAsync(IMAGE_DIR);
    if (info.exists) {
      await FileSystem.deleteAsync(IMAGE_DIR, { idempotent: true });
    }
  } catch {
    // 写真の削除失敗はデータ操作を妨げない
  }
}

/** アプリ内に保存した写真を削除する（images/ 配下のファイル名だけを受け付ける） */
export async function deleteStoredImageAsync(
  stored: string | undefined,
): Promise<void> {
  if (!stored) return;
  let target: string | undefined;
  if (STORED_NAME_PATTERN.test(stored)) {
    target = `${IMAGE_DIR}${stored}`;
  } else if (stored.startsWith(IMAGE_DIR)) {
    target = stored; // 旧形式（現在のコンテナ内のみ削除可能）
  }
  if (!target) return;
  try {
    await FileSystem.deleteAsync(target, { idempotent: true });
  } catch {
    // 写真の削除失敗はデータ操作を妨げない
  }
}
