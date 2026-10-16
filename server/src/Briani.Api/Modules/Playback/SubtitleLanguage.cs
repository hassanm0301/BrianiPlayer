using System.Text.RegularExpressions;
namespace Briani.Api.Modules.Playback;

/// Reads a language tag from a sidecar name such as "Film.en.srt",
/// "Film.pt-BR.srt" or "Film.2012.eng.forced.srt". Only ISO 639 codes count,
/// and the first name segment (the title) is never taken as a language.
public static partial class SubtitleLanguage
{
    private static readonly HashSet<string> TwoLetter = new(
        ("aa ab ae af ak am an ar as av ay az ba be bg bh bi bm bn bo br bs ca ce ch co cr cs cu cv cy da de dv dz ee el en eo es et eu " +
         "fa ff fi fj fo fr fy ga gd gl gn gu gv ha he hi ho hr ht hu hy hz ia id ie ig ii ik io is it iu ja jv ka kg ki kj kk kl km kn ko kr " +
         "ks ku kv kw ky la lb lg li ln lo lt lu lv mg mh mi mk ml mn mr ms mt my na nb nd ne ng nl nn no nr nv ny oc oj om or os pa pi pl ps " +
         "pt qu rm rn ro ru rw sa sc sd se sg si sk sl sm sn so sq sr ss st su sv sw ta te tg th ti tk tl tn to tr ts tt tw ty ug uk ur uz ve " +
         "vi vo wa wo xh yi yo za zh zu").Split(' '));
    private static readonly HashSet<string> ThreeLetter = new(
        ("ara arm hye baq eus bel ben bos bul bur mya cat chi zho cze ces dan dut nld eng est fil fin fre fra geo kat ger deu gle glg gre ell " +
         "heb hin hrv hun ice isl ind ita jpn kan kaz khm kor lao lat lav lit mac mkd mal mar may msa mon nep nor nob nno per fas pol por " +
         "rum ron rus slo slk slv spa srp swa swe tam tel tgl tha tur ukr urd uzb vie wel cym yid zul").Split(' '));
    private static readonly HashSet<string> Qualifiers = new(["forced", "sdh", "cc", "hi", "default", "full", "signs"], StringComparer.OrdinalIgnoreCase);

    [GeneratedRegex("^(?<lang>[A-Za-z]{2,3})(?:[-_](?<region>[A-Za-z]{2}|[0-9]{3}))?$")]
    private static partial Regex Tag();

    public static string? FromFileName(string name)
    {
        var parts = Path.GetFileNameWithoutExtension(name).Split('.');
        for (var i = parts.Length - 1; i >= 1; i--)
        {
            if (Qualifiers.Contains(parts[i])) continue;
            var match = Tag().Match(parts[i]);
            if (!match.Success) return null;
            var lang = match.Groups["lang"].Value.ToLowerInvariant();
            if (!(lang.Length == 2 ? TwoLetter : ThreeLetter).Contains(lang)) return null;
            return match.Groups["region"].Success ? $"{lang}-{match.Groups["region"].Value.ToUpperInvariant()}" : lang;
        }
        return null;
    }
}
