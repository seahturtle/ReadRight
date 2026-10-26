import SwiftUI

/// The research behind ReadRight: what each source supports, what it can't establish, and how the app uses it.
/// Numbers are repeated only as each source reports them.
struct EvidenceView: View {
    private struct Source: Identifiable {
        let id = UUID()
        let citation: String
        let url: String
        let supports: String
        let cannot: String
        let use: String
    }

    private let sources: [Source] = [
        Source(
            citation: "Melby-Lervåg, Lyster & Hulme (2012). Phonological skills and their role in learning to read: a meta-analytic review. Psychological Bulletin.",
            url: "https://pubmed.ncbi.nlm.nih.gov/22250824/",
            supports: "Across 235 studies, children with dyslexia were well behind same-age peers on phonemic awareness, and phonemic awareness was the strongest link to word reading.",
            cannot: "Group differences don't identify any one child.",
            use: "Echo Cave asks children to take the first sound off a word, a phonemic awareness task."
        ),
        Source(
            citation: "Snowling & Melby-Lervåg (2016). Oral language deficits in familial dyslexia: a meta-analysis and review. Psychological Bulletin.",
            url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC4824243/",
            supports: "45% of children with a parent or sibling with dyslexia developed it, compared with 11.6% of other children. Children at family risk were also behind on letter knowledge, rapid naming and repeating made-up words before school.",
            cannot: "Most children with family history (55%) didn't develop dyslexia, and many parents were never diagnosed.",
            use: "The optional background question about family history, and why the summary mentions it."
        ),
        Source(
            citation: "Meta-analysis of rapid automatized naming and reading (137 studies, 28,826 participants). University of Algarve repository.",
            url: "https://sapientia.ualg.pt/entities/publication/26e2bd16-bf52-4ab5-81f8-9d00a7381976/full",
            supports: "How quickly children name familiar things (colors, objects, letters) is moderately related to reading (r = .43).",
            cannot: "Slow naming alone isn't dyslexia, and shyness or speech can slow it down.",
            use: "Firefly Dash times how long it takes to name 20 colored fireflies."
        ),
        Source(
            citation: "Meta-analysis of the nonword reading deficit in specific reading disorder (34 studies). PubMed.",
            url: "https://pubmed.ncbi.nlm.nih.gov/17009769/",
            supports: "Children with reading disorder read made-up words less well than even younger children reading at the same level.",
            cannot: "Results mean little before decoding has been taught, and speech recognizers can't score made-up words reliably.",
            use: "Word Woods mixes made-up creature names with real words, and a grown-up marks the made-up ones."
        ),
        Source(
            citation: "International Dyslexia Association (2025). Definition of dyslexia.",
            url: "https://dyslexiaida.org/definition-of-dyslexia/",
            supports: "Dyslexia involves difficulty with word reading and spelling, in accuracy, speed or both, that persists even with teaching that works for other children.",
            cannot: "A definition, not a test.",
            use: "Why the summary notes when an area looks hard on more than one day."
        ),
        Source(
            citation: "International Dyslexia Association. Universal screening: K–2 reading.",
            url: "https://dyslexiaida.org/universal-screening-k-2-reading/",
            supports: "Good screeners test several separate skills (sound awareness, letter sounds, rapid naming, word and nonsense-word reading), use standard directions, and are repeated during the year.",
            cannot: "It describes school screeners, not this app.",
            use: "Chose the five areas ReadRight observes."
        ),
        Source(
            citation: "National Center on Improving Literacy. Screening for dyslexia, and understanding classification accuracy.",
            url: "https://improvingliteracy.org/wp-content/uploads/2025/07/ncil-understanding-literacy-screening_-classification-accuracy.pdf",
            supports: "No screener avoids both false alarms and misses. Screens built on a single measure flag too many children, and screening isn't a one-time test.",
            cannot: "It's guidance for schools.",
            use: "Why ReadRight shows observations, not a risk score."
        ),
        Source(
            citation: "Rello et al. (2020). Predicting risk of dyslexia with an online gamified test. PLOS ONE.",
            url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC7710040/",
            supports: "A research game in Spanish was 79.8% accurate overall but 69.2% for 7–8 year olds, and the authors say it can't serve as a diagnosis.",
            cannot: "Those numbers hold only for that game and sample.",
            use: "ReadRight makes no accuracy claim, because it hasn't been tested against professional assessments."
        ),
        Source(
            citation: "NIDCD. Reading disability among children with and without specific language impairment.",
            url: "https://www.nidcd.nih.gov/health/statistics/prevalence-percent-within-each-group-children-having-reading-disability-second-and-fourth",
            supports: "About 40% of kindergartners with a language impairment had a reading disability in 2nd grade, compared with about 9% of other children.",
            cannot: "A language impairment needs a speech-language pathologist to identify.",
            use: "The optional background question about early speech and language."
        ),
        Source(
            citation: "California Education Code 53008.",
            url: "https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=EDC&sectionNum=53008",
            supports: "From 2025–26, California public schools screen every K–2 student each year for reading difficulties, including risk for dyslexia, and give families the results.",
            cannot: "It applies to schools, not apps.",
            use: "The summary points families to their school's screening results."
        ),
    ]

    private let signs = [
        "Has trouble with nursery rhymes or noticing words that rhyme",
        "Is slow to learn letter names, even the letters in their own name",
        "Mispronounces familiar words well past the toddler years",
        "Has trouble connecting letters with their sounds",
        "Can't yet sound out short words like cat, or reading mistakes don't match the letters",
        "Doesn't notice that words break into smaller sounds",
        "Says reading is hard, or avoids it",
        "Has a parent, brother or sister who had trouble with reading or spelling",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Research behind ReadRight").themed(.display, 22).foregroundStyle(Theme.ink)
            Text("These sources shaped what ReadRight observes and how carefully it talks about results. ReadRight uses no trained model, gives no score, and uses no dataset of children's data.")
                .themed(.body, 15)
                .foregroundStyle(Theme.inkSoft)

            VStack(alignment: .leading, spacing: 8) {
                Text("Signs to watch for at home").themed(.display, 18).foregroundStyle(Theme.ink)
                bulletList(signs)
                Text("Not every child with these signs has dyslexia, and only a professional evaluation can say. Paraphrased from the Yale Center for Dyslexia & Creativity and the National Center on Improving Literacy.")
                    .themed(.body, 13)
                    .foregroundStyle(Theme.muted)
                Link("Yale: signs of dyslexia", destination: URL(string: "https://www.dyslexia.yale.edu/couldyoubedyslexic.html")!)
                Link("NCIL: signs to watch for by age", destination: URL(string: "https://improvingliteracy.org/resource/understanding-dyslexia-signs-to-watch-for-by-age")!)
            }
            .themed(.body, 15)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.soft))

            ForEach(sources) { source in
                VStack(alignment: .leading, spacing: 6) {
                    Link(source.citation, destination: URL(string: source.url)!)
                        .themed(.display, 15)
                        .foregroundStyle(Theme.earth)
                    labeled("What it supports", source.supports)
                    labeled("What it can't establish", source.cannot)
                    labeled("How ReadRight uses it", source.use)
                }
                .padding(.top, 10)
                .overlay(alignment: .top) { Rectangle().fill(Theme.ink.opacity(0.2)).frame(height: 1) }
            }
        }
    }

    private func labeled(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).themed(.display, 13).foregroundStyle(Theme.ink)
            Text(text).themed(.body, 14).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "What each activity observes", from the prototype: what the child does, what Pip says,
/// what's recorded, and what it can't tell you.
struct ActivitiesExplainerView: View {
    private struct Row: Identifiable {
        let activity: Activity
        let childDoes: String
        let pipSays: String
        let observed: String
        let cannot: String
        var id: Activity { activity }
    }

    private let rows: [Row] = [
        Row(
            activity: .soundSprings,
            childDoes: "Sees a picture and hears its word, such as bat, then taps its first letter from three stones.",
            pipSays: "“Listen to the word, then tap the letter it starts with.”",
            observed: "Time to the first tap, first-try match, whether a wrong pick was a mirror-image letter (b/d) or a sound-alike (b/p), and hints.",
            cannot: "Whether a mix-up comes from hearing, vision, attention, or simply not having learned that letter yet. Time includes listening."
        ),
        Row(
            activity: .echoCave,
            childDoes: "Hears a word, such as snail, and says it without its first sound (nail).",
            pipSays: "“Say snail, without its first sound.”",
            observed: "Time from the green light to the first sound, whether Pip heard the answer (on this iPhone), a grown-up's mark, and single sounds vs blends.",
            cannot: "Why a puzzle was hard: the directions, the accent, or the skill. Young children often need practice to understand the game."
        ),
        Row(
            activity: .wordWoods,
            childDoes: "Reads short real words and made-up creature names out loud after the green light.",
            pipSays: "“Wait for the green light, then read the word to me. Any way you say it is fine!”",
            observed: "Time from the word appearing to the first sound, the on-device word check for real words (matched or unclear), and a grown-up's marks.",
            cannot: "Exact pronunciation. Speech recognition is less reliable for children, so unclear answers aren't counted. Made-up words need a grown-up's judgment."
        ),
        Row(
            activity: .fireflyDash,
            childDoes: "Practices one row, then names 20 colored fireflies as fast as they can.",
            pipSays: "“When the light turns green, say every color, row by row!”",
            observed: "Time to the first color, total naming time from the first voice to the last, and whether they named all 20.",
            cannot: "Whether a time is quick or slow for their age, because ReadRight has no age norms. Color naming can be hard for color-blind children."
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What each activity observes").themed(.display, 22).foregroundStyle(Theme.ink)
            Text("Each step records a few plain facts about how the child played. None is scored against other children, and no single one points to a condition.")
                .themed(.body, 15)
                .foregroundStyle(Theme.inkSoft)
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        IslandArt(activity: row.activity).frame(width: 64)
                        Text(row.activity.title).themed(.display, 18).foregroundStyle(Theme.ink)
                    }
                    labeled("Child does", row.childDoes)
                    labeled("Pip says", row.pipSays)
                    labeled("Observed", row.observed)
                    labeled("Can't tell", row.cannot)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.background))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.ink, lineWidth: 2))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Child-friendly design choices").themed(.display, 18).foregroundStyle(Theme.ink)
                bulletList([
                    "No lives, no countdowns, no red marks. A firefly lights up for every try.",
                    "A traffic light shows when to talk: amber means get ready, green means your turn.",
                    "Big stones to tap, and a glowing hint after two tries.",
                    "Larger text, calm motion and spoken instructions in Comfort settings.",
                ])
            }
        }
    }

    private func labeled(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).themed(.display, 13).foregroundStyle(Theme.ink)
            Text(text).themed(.body, 14).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
        }
    }
}
