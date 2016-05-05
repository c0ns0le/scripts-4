using System;
using System.Text;
using System.Web.Configuration;
using System.Reflection;

namespace DecryptHashedPassword
{
    public class MembershipProviderHelper //: System.Web.Security.SqlMembershipProvider
    {
        #region Main
        static void Main(string[] args)
        {
            //TestEncrypt(args);
            TestDecrypt(args);
        }

        private static void TestDecrypt(string[] args)
        {
            var clearPWd = "abc123$";
            var salt = "6XxXPEvRdWec3ZCGJOuP8g==";

            // read encryptedPwd from command-line first argument
            if (args != null & args.Length > 0) { clearPWd = args[0]; }

            var encryptedPwd = MembershipProviderHelper.Encrypt(clearPWd, salt);

            Console.WriteLine("Encrypted: '{0}'", encryptedPwd);
            Console.WriteLine("Decrypted: '{0}'", clearPWd);
        }

        private static void TestEncrypt(string[] args)
        {
            var encryptedPwd = "9UpZMYzsdmEa5d9zfNYeNrccYMzUwJLV3yFGlnDhCxY="; // abc123$

            // read encryptedPwd from command-line first argument
            if (args != null & args.Length > 0) { encryptedPwd = args[0]; }

            var clearPWd = MembershipProviderHelper.GetClearTextPassword(encryptedPwd);

            Console.WriteLine("Encrypted: '{0}'", encryptedPwd);
            Console.WriteLine("Decrypted: '{0}'", clearPWd);
        }
        #endregion


        #region Helper Functions
        private const int SALT_SIZE = 0x10; //16;

        public static string GetClearTextPassword(string encryptedPwd)
        {
            byte[] encodedPassword = Convert.FromBase64String(encryptedPwd);
            //byte[] bytes = base.DecryptPassword(encodedPassword);

            //  return SystemWebProxy.Membership.EncryptOrDecryptData(false, encodedPassword, false);
            //                  Membership.EncryptOrDecryptData => System.Web.Security.MembershipAdapter.EncryptOrDecryptData
            byte[] bytes = EncryptOrDecryptData(encrypt: false, buffer: encodedPassword, useLegacyMode: false);

            if (bytes == null) { return null; }
            return Encoding.Unicode.GetString(bytes, SALT_SIZE, bytes.Length - SALT_SIZE);
        }

        public static string Encrypt(string password, string salt)
        {
            var Instance = new System.Web.Security.SqlMembershipProvider();

            var m = Instance.GetType().GetMethod("EncodePassword", BindingFlags.NonPublic | BindingFlags.Instance);

            var encryptedPassword = (string)m.Invoke(Instance, new object[] { password, System.Web.Security.MembershipPasswordFormat.Encrypted, salt });

	        if (encryptedPassword.Length > 128) { throw new Exception("Invalid Password"); }
	        return encryptedPassword;
        }


        private static byte[] EncryptOrDecryptData(bool encrypt, byte[] buffer, bool useLegacyMode)
        {
            // DevDiv Bugs 137864: Use IVType.None for compatibility with stored passwords even after SP20 compat mode enabled.
            // This is the ONLY case IVType.None should be used.

            // We made changes to how encryption takes place in response to MSRC 10405. Membership needs to opt-out of
            // these changes (by setting signData to false) to preserve back-compat with existing databases.

#pragma warning disable 618 // calling obsolete methods
            //[Obsolete(OBSOLETE_CRYPTO_API_MESSAGE)]
            //internal static byte[] EncryptOrDecryptData(bool fEncrypt, byte[] buf, byte[] modifier, int start, int length,
            //                                           bool useValidationSymAlgo, bool useLegacyMode, IVType ivType, bool signData)
            //
            //http://referencesource.microsoft.com/#System.Web/Configuration/MachineKeySection.cs,1f88f7ca4ce49b65
            //return MachineKeySection.EncryptOrDecryptData(/*fEncrypt:*/ encrypt,
            //                                             /*buf:*/ buffer,
            //                                             /*modifier:*/ (byte[])null,
            //                                             /*start:*/ 0,
            //                                             /*length:*/ buffer.Length,
            //                                             /*useValidationSymAlgo:*/ false,
            //                                             /*useLegacyMode:*/ useLegacyMode,
            //                                             /*ivType:*/ 0, //IVType.None,
            //                                             /*signData:*/ false);
            Type enumIVType = typeof(MachineKeySection).Assembly.GetType("System.Web.Configuration.IVType");
            object IVTypeNone = enumIVType.GetField("None", BindingFlags.Static | BindingFlags.Public).GetValue(null);
            var method = typeof(MachineKeySection).GetMethod("EncryptOrDecryptData", BindingFlags.Static | BindingFlags.NonPublic, null,
                                                            new Type[] { typeof(bool), typeof(byte[]), typeof(byte[]), typeof(int), typeof(int), typeof(bool), typeof(bool), enumIVType, typeof(bool) }, null);
            return (byte[])method.Invoke(obj: null, parameters: new object[] {
                                                         /*fEncrypt:*/ encrypt,
                                                         /*buf:*/ buffer,
                                                         /*modifier:*/ (byte[])null,
                                                         /*start:*/ 0,
                                                         /*length:*/ buffer.Length,
                                                         /*useValidationSymAlgo:*/ false,
                                                         /*useLegacyMode:*/ useLegacyMode,
                                                         /*ivType:*/ IVTypeNone, // IVType.None,
                                                         /*signData:*/ false
                                                         });
#pragma warning restore 618 // calling obsolete methods
        }
        #endregion
    }
}
