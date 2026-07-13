import React from "react";
import Constants from "expo-constants";
import { LegalPage } from "@/components/LegalPage";

export default function AboutScreen() {
  const version = Constants.expoConfig?.version ?? "1.0.0";
  return (
    <LegalPage
      sections={[
        {
          heading: "家の手入れ記録",
          body: "家電・住宅設備・交換品の「最後にいつ」と「次はいつ」を静かに残す、個人用の履歴台帳です。",
        },
        {
          heading: "バージョン",
          body: version,
        },
        {
          heading: "できること",
          body: "・家電や設備のお手入れ項目の登録\n・実施記録と履歴の確認\n・メーカー、型番、場所、写真の保存\n・次回目安日の自動計算\n・目安日前のローカル通知",
        },
        {
          heading: "できないこと",
          body: "本アプリは、家電や住宅設備の安全性・故障・寿命の診断は行いません。表示される時期は一般的な目安です。実際の時期は製品の取扱説明書やメーカーの案内を優先してください。",
        },
      ]}
    />
  );
}
