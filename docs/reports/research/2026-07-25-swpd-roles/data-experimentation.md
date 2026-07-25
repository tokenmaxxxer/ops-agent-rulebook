# Data, Analytics, and Experimentation Roles in Software Product Development

## Roles

- **Data Analyst**: closer to reporting/BI — dashboards, ad hoc queries, descriptive analysis of historical data. Skills lean Tableau/SQL. [dbt Labs comparison](https://www.getdbt.com/blog/analytics-engineer-vs-data-analyst-vs-data-engineer)
- **Product Analyst**: embedded with product teams, real-time/near-term decision support (funnel diagnosis, A/B test reads, feature adoption), user-psychology-aware, less predictive modeling than data science. [Zippia](https://www.zippia.com/product-analyst-jobs/product-analyst-vs-data-scientist-differences/), [Optimizely](https://www.optimizely.com/insights/blog/data-analysts-vs-product-analysts-vs-pms/), [Towards Data Science](https://towardsdatascience.com/product-analysts-what-is-that-936978e5c215/)
- **Data Scientist**: longer-horizon, model-building work — predictive models, recommendation/personalization systems, causal inference methodology; more Python/ML-heavy. [Zippia](https://www.zippia.com/product-analyst-jobs/product-analyst-vs-data-scientist-differences/)
- **Analytics Engineer** (dbt-defined role): applies software-engineering discipline — version control, testing, modular SQL — to the transformation layer between raw warehouse data and analysis; owns dbt models, not infrastructure. [dbt Labs](https://www.getdbt.com/blog/analytics-engineer-vs-data-analyst-vs-data-engineer), [AltexSoft](https://www.altexsoft.com/blog/analytics-engineer/)
- **Data Engineer**: builds and operates the infrastructure/pipelines that land raw data in the warehouse (ingestion, orchestration, scaling); tools skew Python/Spark/Airflow/cloud infra rather than SQL-modeling. [dataexpert.io](https://www.dataexpert.io/blog/data-engineer-vs-analytics-engineer-key-differences), [ThoughtSpot](https://www.thoughtspot.com/data-trends/data-and-analytics-engineering/analytics-engineer-vs-data-engineer)
- **Experimentation Platform Engineer**: builds/operates the A/B testing infrastructure itself (assignment, metric computation, SRM checks, guardrails) — e.g., Microsoft ExP, Airbnb ERF, Netflix XP, Booking.com's in-house framework. [Microsoft Research ExP](https://www.microsoft.com/en-us/research/group/experimentation-platform-exp/articles/it-takes-a-flywheel-to-fly-kickstarting-and-keeping-the-a-b-testing-momentum/), [Airbnb ERF](https://medium.com/airbnb-engineering/https-medium-com-jonathan-parks-scaling-erf-23fd17c91166), [Netflix XP](https://netflixtechblog.com/experimentation-is-a-major-focus-of-data-science-across-netflix-f67923f8e985)
- **Growth Analyst**: focused on the acquisition/activation/retention/revenue/referral (AARRR) funnel for growth-loop optimization; overlaps with product analyst but scoped to growth metrics specifically. [AARRR pirate metrics overview](https://medium.com/business-model-validation-101/what-are-aarrr-pirate-metrics-81d3c8f9fd56)

## Responsibility boundaries

- **Analytics engineer vs data engineer**: the line is roughly ingestion/infrastructure (data engineer: pipelines, orchestration tools like Airflow, warehouse scaling) vs. transformation/modeling-in-the-warehouse (analytics engineer: dbt models, testing, documentation, semantic/business logic). Analytics engineers "don't cover the full data engineering pipeline and rely less on complex orchestration tools." [dbt Labs](https://www.getdbt.com/blog/analytics-engineer-vs-data-analyst-vs-data-engineer), [dataexpert.io](https://www.dataexpert.io/blog/data-engineer-vs-analytics-engineer-key-differences)
- **Product analyst vs data scientist**: product analysts are oriented to fast, recurring product decisions (exploration, diagnosis, recommendation, A/B readouts) and stay close to the business/product side; data scientists take on longer, more complex modeling work (personalization, forecasting, causal-inference methodology) that underlies platforms rather than single product decisions. [Zippia](https://www.zippia.com/product-analyst-jobs/product-analyst-vs-data-scientist-differences/), [Towards Data Science](https://towardsdatascience.com/product-analysts-what-is-that-936978e5c215/)

## Artifacts produced

- **Tracking plan / event taxonomy**: the spec of events, properties, naming conventions (object-action-context, past-tense verbs, snake_case), PII boundaries, and versioning rules; serves as the single source of truth validated at ingestion (e.g., Segment Protocols via JSON Schema). Consumed by engineers (who instrument), analysts (who query), and governance/data-quality reviewers. [Segment](https://segment.com/docs/protocols/tracking-plan/create/), [Event Taxonomy Playbook](https://productgrowth.in/resources/guides/event-taxonomy-guide/)
- **Metric definition / semantic layer**: canonical, versioned definitions of business metrics computed consistently across dashboards and experiments — e.g., Airbnb's Minerva (12,000+ metrics, 4,000+ dimensions) feeding its experimentation platform ERF, ensuring "metric consistency at scale." Consumed by all data roles plus PMs/execs reading dashboards. [Airbnb metric consistency](https://medium.com/airbnb-engineering/how-airbnb-achieved-metric-consistency-at-scale-f23cc53dea70), [Airbnb consistent data consumption](https://medium.com/airbnb-engineering/how-airbnb-enables-consistent-data-consumption-at-scale-1c0b6a8b9206)
- **Experiment design doc**: states hypothesis, OEC/primary metric, guardrail metrics, sample-size/power calculation, and pre-committed decision rule before data collection begins. Consumed by the analyst/data scientist running the test and the PM who will act on it. [Kohavi OEC](https://www.linkedin.com/pulse/overall-evaluation-criterion-oec-ronny-kohavi), [OEC glossary](https://www.analytics-toolkit.com/glossary/overall-evaluation-criterion/)
- **Pre-registration of hypothesis and threshold**: the metric, minimum effect size, and stop/go rule fixed before looking at data, to prevent post-hoc rationalization. [Kohavi et al. book excerpt](https://experimentguide.com/wp-content/uploads/TrustworthyOnlineControlledExperiments_PracticalGuideToABTesting_Chapter1.pdf)
- **Experiment readout**: reports the OEC and guardrail results, statistical significance, SRM check status, and a recommendation; consumed by PM/leadership as the go/no-go input. [Kohavi/Tang/Xu book](https://www.researchgate.net/publication/339914315_Trustworthy_Online_Controlled_Experiments_A_Practical_Guide_to_AB_Testing)
- **Dashboard**: recurring visualization of metrics for ongoing monitoring, built on the semantic layer; consumed broadly by PM/eng/exec stakeholders.
- **Cohort analysis**: retention/behavior breakdown by acquisition cohort, commonly framed through AARRR or HEART's "Retention" and "Adoption" dimensions; consumed by growth/product teams. [HEART framework](https://kerryrodden.com/heart/)
- **Data quality / SRM check report**: chi-square test comparing observed vs. expected variant allocation ratios; a mismatch invalidates the experiment before any metric is trusted. Common causes include redirect-induced bot loss and lossy instrumentation differentially affecting arms. [Kohavi SRM](https://medium.com/@deepti.agl16/part-i-trustworthy-online-controlled-experiments-a-b-testing-twymans-law-7dc5032073c7), [Twyman's Law](https://atticusli.com/replication-crisis/ab-testing-twymans-law/)

## Handoff points

- **PM → analyst**: the PM poses the business/product question (what decision this data will inform); this determines the OEC choice, per Kohavi's framing that the OEC should reflect long-term objectives rather than short-term proxies like clicks. [Kohavi OEC](https://www.linkedin.com/pulse/overall-evaluation-criterion-oec-ronny-kohavi)
- **Analyst → PM**: the experiment readout — significance, guardrail status, and a recommendation — is the artifact that closes the loop back to the PM for a launch decision. [Kohavi/Tang/Xu book](https://www.researchgate.net/publication/339914315_Trustworthy_Online_Controlled_Experiments_A_Practical_Guide_to_AB_Testing)
- **Engineer → analyst (instrumentation)**: the tracking plan is the contract engineers implement against; Segment Protocols validates events at write-time against it so instrumentation drift doesn't silently corrupt the data the analyst later queries. [Segment Protocols](https://segment.com/docs/protocols/tracking-plan/create/)
- **Failure mode — instrumentation added too late**: multiple practitioner sources document that when metrics are defined post-launch rather than pre-launch, teams end up "measuring the spike, calling it success, and moving on" because the metric that would have caught failure (activation rate, feature-specific NPS) was never instrumented in time; patching gaps after the fact via data engineering "cures the symptoms... rather than the underlying problem" and adds pipeline complexity. [Userpilot](https://userpilot.com/blog/product-analytics/), [DEV Community](https://dev.to/webmasterid/instrumentation-quality-is-product-infrastructure-1jkh)

## Gates and decision criteria

- **Pre-registration of metric/threshold before data collection**: the decision rule (effect size, significance threshold) is fixed before running the experiment, specifically to block post-hoc metric shopping. [Trustworthy Online Controlled Experiments, Ch.1](https://experimentguide.com/wp-content/uploads/TrustworthyOnlineControlledExperiments_PracticalGuideToABTesting_Chapter1.pdf)
- **SRM check before trusting a result**: a Sample Ratio Mismatch (observed variant split diverging from expected, e.g. not 50/50) invalidates the result until root-caused; common causes are bot/redirect loss and lossy instrumentation that differs by arm. [Kohavi SRM summary](https://medium.com/@weonhyeok.chung/part-i-book-trustworthy-online-controlled-experiments-9fbf9ef2a6a8)
- **Twyman's Law as a standing gate**: "any figure that looks interesting or different is usually wrong" — surprising wins are first suspects for instrumentation bugs, data leaks, or segment contamination, not celebrated. [Atticus Li](https://atticusli.com/replication-crisis/ab-testing-twymans-law/), [InsightHunt](https://insighthunt.org/methodologies/m-610)
- **Guardrail-metric violation blocking a launch**: Airbnb's Experiment Guardrails framework flags ~25 experiments/month for escalation; of those, roughly 80% still launch after stakeholder review and 20% are stopped before launch — guardrail breach triggers review, not automatic kill. [Airbnb guardrails](https://medium.com/airbnb-engineering/designing-experimentation-guardrails-ed6a976ec669)
- **Minimum sample size / power**: computed pre-experiment as part of the design doc, standard practice per Kohavi et al.; exact numeric thresholds are org-specific and not independently sourced here [unsourced beyond general framework citation above].
- **Who decides trustworthiness**: at Booking.com, "experimenters are responsible for the quality and the decision of the experiment" under a democratized model rather than a central review board — decisions are explicitly framed as not made by HiPPO (highest-paid person's opinion). [Booking.com culture](https://brettgfriedman.medium.com/how-booking-com-uses-1000s-of-experiments-to-build-a-culture-of-scientists-b99b349c37d6). Airbnb, by contrast, escalates guardrail-triggering experiments to a stakeholder review before launch, closer to an experiment review board pattern. [Airbnb guardrails](https://medium.com/airbnb-engineering/designing-experimentation-guardrails-ed6a976ec669)

## Practice variation and open debates

- **Experimentation maturity model (Crawl/Walk/Run/Fly)**: derived from Microsoft product-team experience; Crawl and Walk describe early low-volume experimentation, Run means "hundreds of trustworthy experiments a year" (where most surveyed companies sit), and Fly requires platform extensibility beyond what a few practitioners can support manually. [Microsoft Research](https://www.microsoft.com/en-us/research/group/experimentation-platform-exp/articles/it-takes-a-flywheel-to-fly-kickstarting-and-keeping-the-a-b-testing-momentum/)
- **Reported hit-rate of experiments**: per Kohavi's KDD paper "Online Controlled Experiments at Large Scale," roughly a third of tested ideas are statistically significant positive, a third flat, a third significant negative — and at Bing specifically the success rate is reported as lower than that baseline third. [Bing Search Quality Insights](https://blogs.bing.com/search-quality-insights/June-2013/Experimentation-and-Continuous-Improvement-at-Bing/), [Psychology Today summary](https://www.psychologytoday.com/us/blog/toward-a-more-critically-discerning-world/202512/a-worthless-headline-how-bings-idea-was-their)
- **Centralized vs embedded analysts**: centralized teams favor consistency/governance and reduce cognitive load early on but risk disconnecting from business priorities; embedded teams gain speed and department alignment but cause knowledge fragmentation and rebuild cost on turnover; hybrid models (central strategy/governance + embedded execution) are the commonly recommended middle path as orgs scale. [dbt Labs data team structure](https://www.getdbt.com/blog/data-team-structure), [Sigma](https://www.sigmacomputing.com/blog/data-org-dilemma)
- **Democratized vs centralized experimentation platforms**: Booking.com democratizes — anyone can launch a test, ~1,000 concurrent experiments running at any time, ~25,000/year, deployable across 75 countries/43 languages in under an hour, explicitly rejecting HiPPO-driven decisions. [Silicon Canals](https://siliconcanals.com/sc-n-booking-com-still-runs-on-the-internal-a-b-testing-framework-its-engineers-wrote-in-amsterdam-in-the-mid-2000s-with-no-major-rewrite-since-and-at-any-given-moment-it-is-running-more-than-1000/), [Marpipe](https://www.marpipe.com/blog/how-booking-com-uses-1000s-of-experiments). Netflix instead built a "science-centric" platform (XP) where data scientists directly contribute metrics and causal-inference methods in Python/R, blending platform-engineering with a more specialist-driven model. [Netflix TechBlog](https://netflixtechblog.com/experimentation-is-a-major-focus-of-data-science-across-netflix-f67923f8e985)
- **Ship-and-measure vs measure-then-ship**: not independently sourced in this pass beyond the general instrumentation-timing failure mode above [unsourced].
- **HiPPO override**: explicitly named and rejected as a norm at Booking.com ("product decisions not made by HiPPO... but by tests"), implying the debate is real enough that mature experimentation cultures define themselves partly in opposition to it. [Booking.com culture](https://brettgfriedman.medium.com/how-booking-com-uses-1000s-of-experiments-to-build-a-culture-of-scientists-b99b349c37d6)

## Sources

- https://www.getdbt.com/blog/analytics-engineer-vs-data-analyst-vs-data-engineer
- https://www.dataexpert.io/blog/data-engineer-vs-analytics-engineer-key-differences
- https://www.thoughtspot.com/data-trends/data-and-analytics-engineering/analytics-engineer-vs-data-engineer
- https://www.altexsoft.com/blog/analytics-engineer/
- https://www.zippia.com/product-analyst-jobs/product-analyst-vs-data-scientist-differences/
- https://www.optimizely.com/insights/blog/data-analysts-vs-product-analysts-vs-pms/
- https://towardsdatascience.com/product-analysts-what-is-that-936978e5c215/
- https://experimentguide.com/wp-content/uploads/TrustworthyOnlineControlledExperiments_PracticalGuideToABTesting_Chapter1.pdf
- https://www.researchgate.net/publication/339914315_Trustworthy_Online_Controlled_Experiments_A_Practical_Guide_to_AB_Testing
- https://medium.com/@deepti.agl16/part-i-trustworthy-online-controlled-experiments-a-b-testing-twymans-law-7dc5032073c7
- https://medium.com/@weonhyeok.chung/part-i-book-trustworthy-online-controlled-experiments-9fbf9ef2a6a8
- https://atticusli.com/replication-crisis/ab-testing-twymans-law/
- https://insighthunt.org/methodologies/m-610
- https://www.microsoft.com/en-us/research/group/experimentation-platform-exp/articles/it-takes-a-flywheel-to-fly-kickstarting-and-keeping-the-a-b-testing-momentum/
- https://blogs.bing.com/search-quality-insights/June-2013/Experimentation-and-Continuous-Improvement-at-Bing/
- https://blogs.bing.com/search-quality-insights/August-2013/Large-Scale-Experimentation-at-Bing
- https://www.psychologytoday.com/us/blog/toward-a-more-critically-discerning-world/202512/a-worthless-headline-how-bings-idea-was-their
- https://kerryrodden.com/heart/
- https://research.google.com/pubs/archive/36299.pdf
- https://medium.com/airbnb-engineering/designing-experimentation-guardrails-ed6a976ec669
- https://medium.com/airbnb-engineering/https-medium-com-jonathan-parks-scaling-erf-23fd17c91166
- https://medium.com/airbnb-engineering/how-airbnb-achieved-metric-consistency-at-scale-f23cc53dea70
- https://medium.com/airbnb-engineering/how-airbnb-enables-consistent-data-consumption-at-scale-1c0b6a8b9206
- https://brettgfriedman.medium.com/how-booking-com-uses-1000s-of-experiments-to-build-a-culture-of-scientists-b99b349c37d6
- https://siliconcanals.com/sc-n-booking-com-still-runs-on-the-internal-a-b-testing-framework-its-engineers-wrote-in-amsterdam-in-the-mid-2000s-with-no-major-rewrite-since-and-at-any-given-moment-it-is-running-more-than-1000/
- https://www.marpipe.com/blog/how-booking-com-uses-1000s-of-experiments
- https://segment.com/docs/protocols/tracking-plan/create/
- https://productgrowth.in/resources/guides/event-taxonomy-guide/
- https://userpilot.com/blog/product-analytics/
- https://dev.to/webmasterid/instrumentation-quality-is-product-infrastructure-1jkh
- https://www.linkedin.com/pulse/overall-evaluation-criterion-oec-ronny-kohavi
- https://www.analytics-toolkit.com/glossary/overall-evaluation-criterion/
- https://medium.com/business-model-validation-101/what-are-aarrr-pirate-metrics-81d3c8f9fd56
- https://www.getdbt.com/blog/data-team-structure
- https://www.sigmacomputing.com/blog/data-org-dilemma
- https://netflixtechblog.com/experimentation-is-a-major-focus-of-data-science-across-netflix-f67923f8e985
