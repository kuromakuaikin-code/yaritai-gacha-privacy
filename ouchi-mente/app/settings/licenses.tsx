import React, { useMemo } from "react";
import { SectionList, StyleSheet, Text, View } from "react-native";
import ossLicenses from "@/legal/oss-licenses.json";
import { LICENSE_TEXTS } from "@/legal/license-texts";
import { colors, fontSize, spacing } from "@/theme";

type OssEntry = {
  /** パッケージ名 */
  n: string;
  /** バージョン */
  v: string;
  /** ライセンス種別 */
  l: string;
  /** 作者（あれば） */
  p?: string;
};

const INTRO =
  "本アプリは、以下のオープンソースソフトウェアを利用して作られています。" +
  "各ソフトウェアの著作権は、それぞれの作者・貢献者に帰属します。" +
  "主要なライセンスの全文は一覧の末尾に記載しています。";

export default function LicensesScreen() {
  const sections = useMemo(() => {
    const entries = ossLicenses as OssEntry[];
    const byLicense = new Map<string, OssEntry[]>();
    for (const entry of entries) {
      const list = byLicense.get(entry.l) ?? [];
      list.push(entry);
      byLicense.set(entry.l, list);
    }
    const packageSections = [...byLicense.entries()]
      .sort((a, b) => b[1].length - a[1].length)
      .map(([license, list]) => ({
        title: `${license}（${list.length}件）`,
        data: list.map(
          (e) => `${e.n} ${e.v}${e.p ? `　© ${e.p}` : ""}`,
        ),
      }));
    const textSections = LICENSE_TEXTS.map((t) => ({
      title: `${t.name} ライセンス全文`,
      data: [t.text],
    }));
    return [...packageSections, ...textSections];
  }, []);

  return (
    <SectionList
      style={styles.container}
      contentContainerStyle={styles.content}
      sections={sections}
      keyExtractor={(item, index) => `${index}-${item.slice(0, 40)}`}
      initialNumToRender={40}
      ListHeaderComponent={<Text style={styles.intro}>{INTRO}</Text>}
      renderSectionHeader={({ section }) => (
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>{section.title}</Text>
        </View>
      )}
      renderItem={({ item }) => <Text style={styles.entry}>{item}</Text>}
    />
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl },
  intro: {
    fontSize: fontSize.md,
    color: colors.textSecondary,
    lineHeight: 22,
    marginBottom: spacing.md,
  },
  sectionHeader: {
    backgroundColor: colors.background,
    paddingTop: spacing.lg,
    paddingBottom: spacing.sm,
  },
  sectionTitle: {
    fontSize: fontSize.md,
    fontWeight: "700",
    color: colors.text,
  },
  entry: {
    fontSize: fontSize.sm,
    color: colors.textSecondary,
    lineHeight: 19,
    marginBottom: spacing.xs,
  },
});
