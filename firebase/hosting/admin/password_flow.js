export async function changeInitialPassword({
  user,
  currentPassword,
  newPassword,
  credentialFactory,
  reauthenticate,
  update,
  complete,
  onPasswordUpdated = () => undefined,
}) {
  if (!user?.email) throw new Error("Sign in again with the temporary password.");

  if (currentPassword) {
    const credential = credentialFactory(user.email, currentPassword);
    await reauthenticate(user, credential);
  }

  await update(user, newPassword);
  onPasswordUpdated();

  try {
    await complete();
    await user.getIdToken(true);
  } catch (error) {
    error.passwordUpdated = true;
    throw error;
  }
}
