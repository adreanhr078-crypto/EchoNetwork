using System;
using System.IO;
using System.Linq;
using ElevenEleven.Opening;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UI;

namespace ElevenEleven.Editor
{
    internal static class PactAuthorityReview
    {
        private const string Ready =
            "{\"schema\":\"echo-sector11-campaign-v1\",\"completed\":[\"specimen\",\"archive\",\"reactor\",\"decon\",\"mirror\"]," +
            "\"flags\":{\"specimen\":{\"terminal_read\":true},\"archive\":{\"shard_shizuka\":true,\"shard_yuki\":true,\"shard_sector11\":true,\"archive_decoded\":true}," +
            "\"reactor\":{\"breaker_a_done\":true,\"breaker_b_done\":true},\"decon\":{\"override_done\":true}," +
            "\"mirror\":{\"mirror_inspected\":true,\"override_done\":true},\"lab\":{\"confrontation_done\":true,\"contract_done\":false}}," +
            "\"presentation\":{\"beat\":\"pact\",\"elapsed\":0,\"encounter\":{\"step\":5,\"questions\":7,\"deferred\":false,\"look\":[0,0]}}}";
        private static int checks;

        public static void Run()
        {
            var directory = Environment.GetEnvironmentVariable("ECHO_R02_PACT_FIXTURES");
            if (!Application.isBatchMode || string.IsNullOrWhiteSpace(directory) || Directory.Exists(directory))
                throw new InvalidOperationException("An unused Pact fixture directory is required.");
            Directory.CreateDirectory(directory);
            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene);
            var school = Load("Assets/ElevenEleven/Echo/School/EchoSchool-Tripo-Original.glb");
            var pact = Load("Assets/ElevenEleven/MotionReview/echo_pact72_candidate.glb");
            var wing = Bones(pact).Where(bone => bone.name.StartsWith("Wing", StringComparison.Ordinal)).ToArray();
            Require(Bones(school).Length == 65 && Bones(pact).Length == 72, "The two sourced avatars have 65 and 72 joints.");
            Require(wing.Length == 7 && wing.All(bone => bone.name.EndsWith("Left", StringComparison.Ordinal)),
                "Pact source has seven left-wing bones and no right-wing bones.");
            Require(wing.Count(bone => bone.name == "WingRootLeft") == 1, "Pact source has one anatomical left wing root.");
            pact.SetActive(false);

            var path = Path.Combine(directory, "sector11_campaign_v1.json");
            var current = NativeCampaignPact.Load(path);
            Require(!current.HasEarnedPact && !current.Confirm() && school.activeInHierarchy && !pact.activeInHierarchy,
                "Fresh progress cannot trigger the Pact avatar.");
            File.WriteAllText(path, Ready.Replace("\"step\":5", "\"step\":4"));
            current = NativeCampaignPact.Load(path);
            Require(!current.HasEarnedPact && !current.Confirm(), "The choice stays unavailable before the consent step.");
            File.WriteAllText(path, Ready);
            current = NativeCampaignPact.Load(path);
            Require(current.AwaitsConsent && !current.HasEarnedPact, "Entering the decision displays School.");
            var defer = new GameObject("Defer", typeof(RectTransform), typeof(Button)).GetComponent<Button>();
            defer.onClick.AddListener(() => Require(current.Defer(), "Defer writes the pending encounter."));
            defer.onClick.Invoke();
            current = NativeCampaignPact.Load(path);
            Require(!current.AwaitsConsent && !current.HasEarnedPact && !current.Confirm(),
                "Reloading a deferred encounter cannot grant the Pact.");
            Require(current.Reopen() && current.AwaitsConsent, "A deliberate return reopens consent.");

            using (var locked = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
                Require(!current.Confirm() && !current.HasEarnedPact && !pact.activeInHierarchy,
                    "A failed save cannot reveal Pact72.");
            var staleController = NativeCampaignPact.Load(path);
            var confirm = new GameObject("Accept the pact", typeof(RectTransform), typeof(Button)).GetComponent<Button>();
            confirm.onClick.AddListener(() =>
            {
                if (!current.Confirm()) return;
                school.SetActive(false);
                pact.SetActive(true);
            });
            confirm.onClick.Invoke();
            Require(current.HasEarnedPact && !school.activeInHierarchy && pact.activeInHierarchy,
                "The explicit button and durable write switch the visible avatar.");
            Require(!staleController.Confirm(), "A concurrent controller cannot reaccept the same consent.");
            Require(!current.Confirm() && !current.Defer(), "Repeated clicks and late defer cannot rewrite the decision.");
            Require(NativeCampaignPact.Load(path).HasEarnedPact, "A new campaign reader restores the earned Pact.");
            var accepted = File.ReadAllText(path);
            File.WriteAllText(path, "{invalid");
            Require(!NativeCampaignPact.Load(path).HasEarnedPact, "A corrupt accepted primary recovers the last valid pending backup.");

            var legacy = Path.Combine(directory, "legacy-accepted.json");
            var legacyJson = Ready.Substring(0, Ready.IndexOf(",\"presentation\"", StringComparison.Ordinal)) + "}";
            File.WriteAllText(legacy, legacyJson.Replace("\"contract_done\":false", "\"contract_done\":true"));
            Require(NativeCampaignPact.Load(legacy).HasEarnedPact, "An authentic legacy accepted state restores without a cursor.");
            Require(accepted.Contains("\"contract_done\":true"), "The recorded acceptance remains explicit.");
            Debug.Log($"R02_PACT_AUTHORITY_REVIEW_PASS {checks} checks");
            EditorApplication.Exit(0);
        }

        private static GameObject Load(string path)
        {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (prefab == null) throw new FileNotFoundException("Missing avatar source.", path);
            return (GameObject)PrefabUtility.InstantiatePrefab(prefab);
        }

        private static Transform[] Bones(GameObject model) => model.GetComponentsInChildren<SkinnedMeshRenderer>(true)
            .SelectMany(renderer => renderer.bones).Distinct().ToArray();

        private static void Require(bool condition, string description)
        {
            if (!condition) throw new InvalidOperationException(description);
            checks++;
        }
    }
}
