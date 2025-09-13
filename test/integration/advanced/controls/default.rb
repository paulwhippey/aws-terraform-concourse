web_url = input('web_url')

require_relative '../../libraries/concourse_util'

wait("https://#{web_url}")

concourse_web = get("https://#{web_url}")
concourse_web_code = JSON.parse(concourse_web.code)

describe concourse_web_code do
  it { should cmp 200 }
end
