import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { Request, Response } from "express";

admin.initializeApp();
const db = admin.firestore();

export const generateCatalogLinkHttp = onRequest(
  { cors: true },
  async (req: Request, res: Response) => {
    try {
      // -------------------------------------------------
      // 1. Verifica o header Authorization
      // -------------------------------------------------
      const authHeader = req.headers.authorization;
      if (!authHeader?.startsWith("Bearer ")) {
        res.status(401).json({ error: "Token ausente" });
        return;                     // <-- sai da função
      }

      const idToken = authHeader.split("Bearer ")[1];

      // -------------------------------------------------
      // 2. Verifica o token
      // -------------------------------------------------
      let decoded;
      try {
        decoded = await admin.auth().verifyIdToken(idToken);
      } catch (e) {
        res.status(401).json({ error: "Token inválido" });
        return;
      }

      const uid = decoded.uid;

      // -------------------------------------------------
      // 3. Verifica permissão (admin / revendedor)
      // -------------------------------------------------
      const userDoc = await db.collection("users").doc(uid).get();
      const perfil = userDoc.data()?.isPerfil as string | undefined;

      if (!["admin", "revendedor"].includes(perfil ?? "")) {
        res.status(403).json({ error: "Permissão negada" });
        return;
      }

      // -------------------------------------------------
      // 4. Lê o catalogId do body
      // -------------------------------------------------
      const { catalogId } = req.body;
      if (!catalogId) {
        res.status(400).json({ error: "catalogId obrigatório" });
        return;
      }

      // -------------------------------------------------
      // 5. Cria o link temporário
      // -------------------------------------------------
      const linkId = db.collection("tempLinks").doc().id;
      const expiresAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 24 * 60 * 60 * 1000) // 24h
      );

      await db.collection("tempLinks").doc(linkId).set({
        catalogId,
        createdBy: uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
      });

      const link = `https://app-innovaro-showcase.web.app/share/${linkId}`;

      // -------------------------------------------------
      // 6. Responde com JSON (sem return)
      // -------------------------------------------------
      res.status(200).json({ link });
    } catch (err: any) {
      console.error("Erro inesperado:", err);
      res.status(500).json({ error: err.message ?? "Erro interno" });
    }
  }
);
// ========================================
// 2. BUSCAR CATÁLOGO POR LINK (PÚBLICO)
// ========================================
export const getCatalogByLink = onRequest({ cors: true }, async (req, res) => {
  const linkId = req.query.linkId as string;
  if (!linkId) {
    res.status(400).json({ error: "linkId obrigatório" });
    return;
  }

  const linkDoc = await db.collection("tempLinks").doc(linkId).get();
  if (!linkDoc.exists) {
    res.status(404).json({ error: "Link inválido" });
    return;
  }

  const data = linkDoc.data()!;
  if (data.expiresAt.toDate() < new Date()) {
    await linkDoc.ref.delete();
    res.status(410).json({ error: "Link expirado" });
    return;
  }

  const catalogDoc = await db.collection("catalogos").doc(data.catalogId).get();
  if (!catalogDoc.exists) {
    res.status(404).json({ error: "Catálogo não encontrado" });
    return;
  }

  res.json({
    catalog: { id: catalogDoc.id, ...catalogDoc.data() },
  });
});

// ========================================
// 3. CADASTRAR USUÁRIO (Admin Only)
// ========================================
export const cadastrarUsuario = onCall(async (request) => {
  const { auth, data } = request;
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Autenticação necessária.");

  const adminDoc = await db.collection("users").doc(auth.uid).get();
  if (!adminDoc.exists || adminDoc.data()?.isPerfil !== "admin") {
    throw new HttpsError("permission-denied", "Apenas admins.");
  }

  const { email, senha, nome, isPerfil } = data;
  if (!email || !senha || !nome || !isPerfil) {
    throw new HttpsError("invalid-argument", "Todos os campos são obrigatórios.");
  }

  if (!["admin", "revendedor", "cliente"].includes(isPerfil)) {
    throw new HttpsError("invalid-argument", "isPerfil inválido.");
  }

  try {
    const userRecord = await admin.auth().createUser({ email, password: senha, displayName: nome });
    await db.collection("users").doc(userRecord.uid).set({
      email, nome, isPerfil,
      criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      criadoPor: auth.uid,
    });

    return { uid: userRecord.uid, message: "Usuário criado!" };
  } catch (error: any) {
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Email já em uso.");
    }
    throw new HttpsError("internal", error.message);
  }
});