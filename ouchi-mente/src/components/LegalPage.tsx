import React from "react";
import { ScrollView, StyleSheet, Text } from "react-native";
import { colors, fontSize, spacing } from "@/theme";

export type LegalSection = {
  heading?: string;
  body: string;
};

export function LegalPage({ sections }: { sections: LegalSection[] }) {
  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {sections.map((section, index) => (
        <React.Fragment key={index}>
          {section.heading ? (
            <Text style={styles.heading}>{section.heading}</Text>
          ) : null}
          <Text style={styles.body}>{section.body}</Text>
        </React.Fragment>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: spacing.lg, paddingBottom: spacing.xxl, gap: spacing.md },
  heading: {
    fontSize: fontSize.lg,
    fontWeight: "700",
    color: colors.text,
    marginTop: spacing.sm,
  },
  body: {
    fontSize: fontSize.md,
    color: colors.textSecondary,
    lineHeight: 24,
  },
});
