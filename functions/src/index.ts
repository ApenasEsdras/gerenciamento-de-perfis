import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
admin.initializeApp();

/**
 * Gera um link temporário para acesso público aos dados compartilhados
 * Duração máxima: 7 dias (10080 minutos)
 */
export const createTempLink = onCall(
  {
    region: "southamerica-east1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (request) => {
    // 1. Verifica se o usuário está logado
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Você precisa estar logado para gerar um link.");
    }

    const uid = request.auth.uid;
    const data = request.data as { docId: string; minutes?: number };

    // 2. Valida parâmetros
    if (!data.docId) {
      throw new HttpsError("invalid-argument", "docId é obrigatório.");
    }

    const minutes = data.minutes ?? 5;
    if (minutes <= 0 || minutes > 10080) {
      throw new HttpsError(
        "invalid-argument",
        "Duração deve ser entre 1 minuto e 7 dias (10080 minutos)."
      );
    }

    // 3. Gera ID único e seguro
    const accessId = `${uid}_${data.docId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    // 4. Calcula expiração
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + minutes * 60 * 1000)
    );

    // 5. Salva no Firestore
    await admin.firestore().collection("tempAccess").doc(accessId).set({
      targetUid: uid,
      docId: data.docId,
      expiresAt,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      durationMinutes: minutes,
    });

    // 6. Monta URL do link
    const webUrl = `https://app-innovaro-showcase.web.app/?aid=${accessId}`;

    console.log(`Link gerado para UID: ${uid}, docId: ${data.docId}, expira em ${minutes} min`);

    // 7. Retorna o link
    return {
      url: webUrl,
      accessId,
      expiresAt: expiresAt.toDate().toISOString(),
      duration: `${minutes} minutos`,
    };
  }
);

// 2. getTempToken → PÚBLICA via HTTP
export const getTempToken = onRequest(
  {
    region: "southamerica-east1",
    cors: true,
  },
  // teste
  async (req, res) => {
    try {
      console.log("getTempToken chamado com query:", req.query);

      const accessId = req.query.accessId as string;

      if (!accessId) {
        console.log("Erro: accessId ausente");
        res.status(400).json({ error: "Parâmetro 'accessId' é obrigatório" });
        return;
      }

      console.log("Buscando tempAccess:", accessId);
      const snap = await admin.firestore().collection("tempAccess").doc(accessId).get();

      if (!snap.exists) {
        console.log("tempAccess não encontrado");
        res.status(404).json({ error: "Link inválido" });
        return;
      }

      const info = snap.data()!;
      console.log("Dados encontrados:", info);

      if (info.expiresAt.toDate() < new Date()) {
        console.log("Link expirado");
        res.status(410).json({ error: "Link expirado" });
        return;
      }

      const token = await admin.auth().createCustomToken(info.targetUid, {
        tempAccessId: accessId,
      });

      console.log("Token gerado com sucesso");
      res.json({ token });
    } catch (error: any) {
      console.error("ERRO CRÍTICO em getTempToken:", error);
      res.status(500).json({ error: "Erro interno do servidor" });
    }
  }
);