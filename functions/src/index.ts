// ========================================
// 1. GERAR LINK TEMPORÁRIO (Admin/Revendedor)
// ========================================
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

export const generateCatalogLink = onCall(async (request) => {
  const { auth, data } = request;
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Login necessário.");

  const userDoc = await db.collection("users").doc(auth.uid).get();
  const perfil = userDoc.data()?.isPerfil as string | undefined;
  if (!["admin", "revendedor"].includes(perfil ?? "")) {
    throw new HttpsError("permission-denied", "Apenas admin/revendedor.");
  }

  const { catalogId } = data;
  if (!catalogId) throw new HttpsError("invalid-argument", "catalogId obrigatório.");

  const linkId = db.collection("tempLinks").doc().id;
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 24 * 60 * 60 * 1000)
  );

  await db.collection("tempLinks").doc(linkId).set({
    catalogId,
    createdBy: auth.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt,
  });

  return {
    link: `https://app-innovaro-showcase.web.app/share/${linkId}`
  };
});
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