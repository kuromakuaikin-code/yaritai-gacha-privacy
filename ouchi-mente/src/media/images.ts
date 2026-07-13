import * as FileSystem from "expo-file-system/legacy";
import * as ImagePicker from "expo-image-picker";
import { newId } from "@/db/id";

/**
 * 写真は端末内（アプリのドキュメント領域）にコピーして保存する。
 * 外部への送信は行わない。
 */

const IMAGE_DIR = `${FileSystem.documentDirectory}images/`;

async function ensureImageDir(): Promise<void> {
  const info = await FileSystem.getInfoAsync(IMAGE_DIR);
  if (!info.exists) {
    await FileSystem.makeDirectoryAsync(IMAGE_DIR, { intermediates: true });
  }
}

/**
 * 写真ライブラリから1枚選び、アプリ内にコピーして保存先URIを返す。
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
  const extension = source.includes(".")
    ? source.slice(source.lastIndexOf(".") + 1).toLowerCase()
    : "jpg";
  const destination = `${IMAGE_DIR}${newId()}.${extension}`;
  await FileSystem.copyAsync({ from: source, to: destination });
  return destination;
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

/** アプリ内に保存した写真を削除する（管理外のURIは触らない） */
export async function deleteStoredImageAsync(
  uri: string | undefined,
): Promise<void> {
  if (!uri || !uri.startsWith(IMAGE_DIR)) return;
  try {
    await FileSystem.deleteAsync(uri, { idempotent: true });
  } catch {
    // 写真の削除失敗はデータ操作を妨げない
  }
}
