import { onCall, onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions";
admin.initializeApp();
const db = admin.firestore();

// DESATIVA APP CHECK (APENAS TESTE)
setGlobalOptions({ enforceAppCheck: false });

export const gerarLinkTemporario = onCall(
  { region: "southamerica-east1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new Error("Usuário não autenticado");
    }

    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists || userSnap.data()?.role !== "admin") {
      throw new Error("Apenas admin pode gerar links");
    }

    const tempUid = `temp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const expiresAt = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 24 * 60 * 60 * 1000) // 24h
    );

    await db.collection("users").doc(tempUid).set({
      uid: tempUid,
      role: "cliente",
      isExterno: true,
      criadoPor: uid,
      expiresAt,
      criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    });

    const url = `https://app-innovaro-showcase.web.app/?temp=${tempUid}`;
    return { url }; // <-- RETORNA URL!
  }
);

/* 2. CLIENTE EXTERNO ACESSA LINK */
export const getTokenTemporario = onRequest(
  { region: "southamerica-east1", cors: true },
  async (req, res) => {
    const { temp } = req.query;
    if (!temp) {
      res.status(400).json({ error: "temp ausente" });
      return;
    }

    const doc = await db.collection("users").doc(temp as string).get();
    if (!doc.exists) {
      res.status(404).json({ error: "Link inválido" });
      return;
    }

    const data = doc.data()!;
    if (data.expiresAt.toDate() < new Date()) {
      await doc.ref.delete();
      res.status(410).json({ error: "Link expirado" });
      return;
    }

    const token = await admin.auth().createCustomToken(temp as string, {
      tempAccess: true,
      role: "cliente",
      isExterno: true,
      criadoPor: data.criadoPor,
    });

    res.json({ token });
    return;
  }
);